# frozen_string_literal: true

module Admin
  class CustomersController < BaseController
    before_action -> { require_permission!("customers.view") }, only: %i[index show]
    before_action -> { require_permission!("customers.manage") },
                  only: %i[new create edit update destroy reactivate merge_review merge duplicate_check]
    before_action :set_customer, only: %i[show edit update destroy reactivate merge_review merge]
    before_action :reject_merged_mutation!, only: %i[edit update destroy]

    def index
      @lifecycle = params[:lifecycle].presence_in(%w[canonical all merged]) || "canonical"
      mode = case @lifecycle
      when "canonical" then :canonical
      when "merged" then :merged
      else :admin_index
      end
      results = Customers::Search.call(query: params[:q], mode: mode, limit: 500)
      @search_results = results
      @customers = results.map(&:customer)
      @q = params[:q].to_s.strip.presence
    end

    def show
      @customer_requests = @customer.customer_requests.includes(:store, :product_variant).admin_ordered.limit(50)
      @merged_aliases = @customer.merged_aliases.admin_ordered if @customer.canonical?
      if Authorization::PermissionEvaluator.allowed?(user: current_user, permission_key: "stored_value.view_activity", store: current_store)
        @stored_value_accounts = @customer.stored_value_accounts
                                          .where(account_type: StoredValueAccount::CUSTOMER_OWNED_TYPES)
                                          .order(:account_type, :opened_at)
        pages = params[:activity_page].is_a?(ActionController::Parameters) ? params[:activity_page] : {}
        @stored_value_activities = @stored_value_accounts.index_with do |account|
          StoredValue::AccountActivity.call(
            account: account,
            actor: current_user,
            permission_key: "stored_value.view_activity",
            page: pages[account.id]
          )
        end
      end
      if Authorization::PermissionEvaluator.allowed?(user: current_user, permission_key: "gift_cards.view", store: current_store)
        @associated_gift_cards = @customer.gift_cards.includes(:gift_card_program, :stored_value_account).order(:created_at)
      end
    end

    def new
      @customer = Customer.new
      @return_to = valid_customer_request_return_path
      load_duplicate_suggestions
    end

    def create
      @customer = Customer.new(customer_params.except(:lock_version))
      @acknowledge_duplicates = params[:acknowledge_duplicates].present?

      if duplicate_block_needed?
        load_duplicate_suggestions
        flash.now[:alert] = "Possible duplicate customers found. Choose an existing customer, or confirm create anyway."
        @return_to = valid_customer_request_return_path
        render :new, status: :unprocessable_entity
        return
      end

      if create_and_audit!(
        @customer,
        action: "customers.create",
        after_values: {
          display_name: @customer.display_name,
          email: @customer.email,
          phone: @customer.phone,
          preferred_contact_method: @customer.preferred_contact_method
        }
      )
        if (return_path = valid_customer_request_return_path)
          uri = URI.parse(return_path)
          query = Rack::Utils.parse_nested_query(uri.query.to_s)
          query["customer_id"] = @customer.id
          redirect_to "#{uri.path}?#{query.to_query}", notice: "Customer created. Continue the customer request."
        else
          redirect_to admin_customer_path(@customer), notice: "Customer created."
        end
      else
        load_duplicate_suggestions
        @return_to = valid_customer_request_return_path
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      load_duplicate_suggestions
    end

    def update
      rescue_stale do
        @acknowledge_duplicates = params[:acknowledge_duplicates].present?
        prospective = @customer.dup
        prospective.assign_attributes(customer_params.except(:lock_version))
        prospective.id = @customer.id

        suggestions = Customers::SuggestDuplicates.call(
          attributes: suggestion_attributes_for(prospective),
          exclude_id: @customer.id
        )
        if suggestions.any? && !@acknowledge_duplicates
          @customer.assign_attributes(customer_params)
          @duplicate_suggestions = suggestions
          flash.now[:alert] = "Possible duplicate customers found. Choose an existing customer, or confirm save anyway."
          render :edit, status: :unprocessable_entity
          return
        end

        if save_and_audit!(
          @customer,
          attrs: customer_params,
          action: "customers.update",
          before_keys: audit_attribute_keys
        )
          redirect_to admin_customer_path(@customer), notice: "Customer updated."
        else
          load_duplicate_suggestions
          render :edit, status: :unprocessable_entity
        end
      end
    end

    def destroy
      if @customer.merged?
        redirect_to admin_customer_path(@customer), alert: "Merged customers cannot be deactivated separately."
        return
      end

      if StoredValueAccount.where(customer_id: @customer.id, account_type: StoredValueAccount::CUSTOMER_OWNED_TYPES)
                           .where.not(status: "closed").where("balance_cents > 0").exists?
        redirect_to admin_customer_path(@customer),
                    alert: "Cannot deactivate a customer with a nonzero store-credit or trade-credit balance."
        return
      end

      mutate_and_audit!(@customer, action: "customers.deactivate") { @customer.update!(active: false) }
      redirect_to admin_customers_path, notice: "Customer deactivated."
    end

    def reactivate
      reactivate_configuration!(
        @customer,
        permission_key: "customers.manage",
        audit_action: "customers.reactivate",
        redirect_path: admin_customer_path(@customer)
      )
    end

    def duplicate_check
      suggestions = Customers::SuggestDuplicates.call(
        attributes: duplicate_check_params,
        exclude_id: params[:exclude_id]
      )
      render json: {
        suggestions: suggestions.map { |s|
          {
            id: s.customer.id,
            display_name: s.customer.display_name,
            email: s.customer.email,
            phone: s.customer.phone,
            match_strength: s.match_strength,
            matched_on: s.matched_on,
            path: admin_customer_path(s.customer)
          }
        }
      }
    end

    def merge_review
      @survivor = Customer.canonical.active.find_by(id: params[:survivor_id])
      @source = @customer
      unless @survivor
        redirect_to admin_customer_path(@source), alert: "Select an active canonical survivor to merge into."
        return
      end

      if @source.id == @survivor.id
        redirect_to admin_customer_path(@source), alert: "Cannot merge a customer into itself."
        return
      end

      if @source.merged?
        redirect_to admin_customer_path(@source), alert: "Source customer is already merged."
        return
      end

      @active_request_count = @source.customer_requests.where(status: CustomerRequest::ACTIVE_STATUSES).count
      @alias_count = @source.merged_aliases.count
      @idempotency_key = SecureRandom.uuid_v7
    end

    def merge
      survivor = Customer.find(params[:survivor_id])
      begin
        result = Customers::MergeCustomers.call(
          source: @customer,
          survivor: survivor,
          actor: current_user,
          reason: params[:reason],
          idempotency_key: params[:idempotency_key],
          store: current_store,
          expected_source_lock_version: params[:source_lock_version],
          expected_survivor_lock_version: params[:survivor_lock_version]
        )
        notice = if result.replayed
          "Merge already completed for this confirmation."
        else
          "Merged into #{result.survivor.admin_label}."
        end
        redirect_to admin_customer_path(result.survivor), notice: notice
      rescue Customers::Error, Idempotency::OperationService::PayloadMismatchError, ActiveRecord::StaleObjectError => e
        redirect_to merge_review_admin_customer_path(@customer, survivor_id: survivor.id),
                    alert: "Merge could not be completed: #{e.message}"
      end
    end

    private

    def valid_customer_request_return_path
      value = params[:return_to].to_s
      return if value.blank?

      uri = URI.parse(value)
      return unless uri.host.nil? && uri.path == new_admin_customer_request_path

      value
    rescue URI::InvalidURIError
      nil
    end

    def set_customer
      @customer = Customer.find(params[:id])
    end

    def reject_merged_mutation!
      return unless @customer.merged?

      redirect_to admin_customer_path(@customer), alert: "Merged customers are read-only tombstones."
    end

    def audit_attribute_keys
      %w[display_name given_name family_name email phone preferred_contact_method notes active]
    end

    def customer_params
      params.require(:customer).permit(
        :display_name,
        :given_name,
        :family_name,
        :email,
        :phone,
        :preferred_contact_method,
        :notes,
        :lock_version
      )
    end

    def duplicate_check_params
      params.permit(:display_name, :given_name, :family_name, :email, :phone).to_h
    end

    def load_duplicate_suggestions
      attrs = if @customer&.persisted?
        suggestion_attributes_for(@customer)
      else
        customer_params_for_suggestions
      end
      @duplicate_suggestions = Customers::SuggestDuplicates.call(
        attributes: attrs,
        exclude_id: @customer&.id
      )
    rescue ActionController::ParameterMissing
      @duplicate_suggestions = []
    end

    def customer_params_for_suggestions
      params.fetch(:customer, {}).permit(
        :display_name, :given_name, :family_name, :email, :phone
      ).to_h
    end

    def suggestion_attributes_for(customer)
      {
        display_name: customer.display_name,
        given_name: customer.given_name,
        family_name: customer.family_name,
        email: customer.email,
        phone: customer.phone
      }
    end

    def duplicate_block_needed?
      return false if @acknowledge_duplicates

      suggestions = Customers::SuggestDuplicates.call(
        attributes: suggestion_attributes_for(@customer),
        exclude_id: @customer.id
      )
      @duplicate_suggestions = suggestions
      suggestions.any?
    end
  end
end
