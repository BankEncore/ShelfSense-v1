# frozen_string_literal: true

module Admin
  class StoredValueAdjustmentsController < BaseController
    before_action -> { require_permission!("stored_value.adjust") }
    before_action :set_customer

    def new
      @account = existing_account_for_params
      @account_type = @account&.account_type || requested_account_type
      @reasons = reasons_for(@account_type)
    end

    def create
      @account = account_for_create!
      @account_type = @account.account_type
      reason = StoredValueAdjustmentReason.find(params.require(:reason_id))
      direction = params.require(:direction)
      amount_cents = Money::ParseCents.call(params[:amount])
      raise StoredValue::Error, "amount is required" if amount_cents.nil?

      approved_by = approver_if_required!(direction: direction, amount_cents: amount_cents, reason: reason)
      StoredValue::Adjust.call(
        account: @account,
        direction: direction,
        amount_cents: amount_cents,
        reason: reason,
        store: operational_store!,
        performed_by: current_user,
        approved_by: approved_by,
        source_id: @account.id,
        idempotency_key: params[:idempotency_key].presence || SecureRandom.uuid_v7,
        customer_explanation: params[:customer_explanation],
        internal_notes: params[:internal_notes]
      )
      redirect_to admin_customer_path(@customer), notice: "Stored-value adjustment posted."
    rescue StoredValue::Error, Money::ParseCents::Error, ArgumentError, ActiveRecord::RecordNotFound => e
      @account ||= existing_account_for_params
      @account_type = @account&.account_type || requested_account_type
      @reasons = reasons_for(@account_type)
      flash.now[:alert] = e.message
      render :new, status: :unprocessable_entity
    end

    private

    def set_customer
      @customer = Customer.find(params[:customer_id])
    end

    def existing_account_for_params
      if params[:stored_value_account_id].present?
        customer_owned_accounts.find(params[:stored_value_account_id])
      else
        customer_owned_accounts.where(account_type: requested_account_type).where.not(status: "closed").order(:id).first
      end
    end

    def account_for_create!
      if params[:stored_value_account_id].present?
        customer_owned_accounts.find(params[:stored_value_account_id])
      else
        StoredValue::EnsureCustomerAccount.call(customer: @customer, account_type: requested_account_type)
      end
    end

    def customer_owned_accounts
      @customer.stored_value_accounts.where(account_type: StoredValueAccount::CUSTOMER_OWNED_TYPES)
    end

    def requested_account_type
      params[:account_type].presence_in(StoredValueAccount::CUSTOMER_OWNED_TYPES) || "store_credit"
    end

    def reasons_for(account_type)
      StoredValueAdjustmentReason.active.admin_ordered.select { |reason| Array(reason.allowed_account_types).include?(account_type) }
    end

    def operational_store!
      current_store || Store.active.order(:name).first || raise(StoredValue::Error, "a store is required")
    end

    def approver_if_required!(direction:, amount_cents:, reason:)
      return unless StoredValue::Adjust.second_user_required?(direction: direction, amount_cents: amount_cents, reason: reason, account: @account)

      StoredValue::AuthenticateApprover.call(
        username: params[:approver_username],
        password: params[:approver_password],
        performer: current_user,
        permission_key: "stored_value.adjust",
        store: operational_store!
      )
    end
  end
end
