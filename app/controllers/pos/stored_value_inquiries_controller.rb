# frozen_string_literal: true

module Pos
  class StoredValueInquiriesController < BaseController
    before_action :prepare_surface
    before_action :require_gift_cards_view!, only: :admin_prefix_last_four

    def show
    end

    def exact_number
      raw = params[:card_number].to_s
      card = GiftCards::Lookup.by_number(raw)
      if card.nil?
        flash.now[:alert] = "No gift card matched that number."
        render :show, status: :unprocessable_entity
        return
      end

      @exact_card = card
      @exact_activity = StoredValue::AccountActivity.call(
        account: card.stored_value_account,
        actor: current_user,
        permission_key: "pos.transact",
        page: 1
      )
      @continuations = Pos::StoredValueInquiryContinuations.call(
        state: @state,
        actor: current_user,
        store: current_store,
        gift_card: card
      )
      render :show
    end

    def store_credit
      if params[:customer_id].present?
        customer = Customer.active.canonical.find_by(id: params[:customer_id])
        unless customer
          flash.now[:alert] = "Customer not found."
          render :show, status: :unprocessable_entity
          return
        end

        @store_credit_customer = customer
        @store_credit_account = customer.stored_value_accounts.find_by(account_type: "store_credit")
        @continuations = Pos::StoredValueInquiryContinuations.call(
          state: @state,
          actor: current_user,
          store: current_store,
          store_credit_customer: customer
        )
        render :show
        return
      end

      query = params[:customer_query].to_s.strip
      if query.blank?
        flash.now[:alert] = "Enter a customer name, email, or phone."
        render :show, status: :unprocessable_entity
        return
      end

      @store_credit_matches = Customers::Search.call(query: query, mode: :operational, limit: 20)
      if @store_credit_matches.empty?
        flash.now[:alert] = "No matching customers."
        render :show, status: :unprocessable_entity
        return
      end

      render :show
    end

    def admin_prefix_last_four
      result = GiftCards::AdminInquiry.call(
        prefix: params[:number_prefix],
        last_four: params[:number_last_four],
        actor: current_user,
        store: current_store
      )
      case result.status
      when :found
        @admin_card = result.card
        @admin_activity = StoredValue::AccountActivity.call(
          account: result.card.stored_value_account,
          actor: current_user,
          permission_key: "gift_cards.view",
          page: 1
        )
      when :ambiguous
        @admin_candidates = result.candidates
        flash.now[:alert] = "Several cards share that prefix and last four. Choose a masked candidate."
      else
        flash.now[:alert] = GiftCards::GENERIC_INQUIRY_FAILURE
      end
      render :show, status: result.status == :found ? :ok : :unprocessable_entity
    rescue GiftCards::Error => e
      flash.now[:alert] = e.message
      render :show, status: :unprocessable_entity
    end

    private

    def prepare_surface
      prepare_inquiry_shell!(surface: :stored_value_inquiry)
      @can_admin_inquire = Authorization::PermissionEvaluator.allowed?(
        user: current_user,
        permission_key: "gift_cards.view",
        store: current_store
      )
    end

    def require_gift_cards_view!
      return if @can_admin_inquire

      Audit::Recorder.record!(
        action: "authorization.denied",
        outcome: "denied",
        actor_user: current_user,
        actor_label: current_user.display_name,
        store: current_store,
        reason_code: "gift_cards.view",
        metadata: { path: request.fullpath }
      )
      redirect_to pos_stored_value_inquiry_path(inquiry_register_params),
                  alert: "You are not authorized to perform that action."
    end
  end
end
