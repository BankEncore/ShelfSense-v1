# frozen_string_literal: true

module Pos
  class StoredValueInquiriesController < BaseController
    before_action :prepare_surface
    before_action :require_gift_cards_view!, only: :admin_prefix_last_four

    def show
      restore_inquiry_result!
    end

    def exact_number
      raw = params[:card_number].to_s
      card = GiftCards::Lookup.by_number(raw)
      if card.nil?
        redirect_to pos_stored_value_inquiry_path(inquiry_register_params),
                    alert: "No gift card matched that number."
        return
      end

      flash[:sv_inquiry] = { "exact_gift_card_id" => card.id }
      redirect_to pos_stored_value_inquiry_path(inquiry_register_params)
    end

    def store_credit
      if params[:customer_id].present?
        customer = Customer.active.canonical.find_by(id: params[:customer_id])
        unless customer
          redirect_to pos_stored_value_inquiry_path(inquiry_register_params),
                      alert: "Customer not found."
          return
        end

        flash[:sv_inquiry] = { "store_credit_customer_id" => customer.id }
        redirect_to pos_stored_value_inquiry_path(inquiry_register_params)
        return
      end

      query = params[:customer_query].to_s.strip
      if query.blank?
        redirect_to pos_stored_value_inquiry_path(inquiry_register_params),
                    alert: "Enter a customer name, email, or phone."
        return
      end

      matches = Customers::Search.call(query: query, mode: :operational, limit: 20)
      if matches.empty?
        redirect_to pos_stored_value_inquiry_path(inquiry_register_params.merge(customer_query: query)),
                    alert: "No matching customers."
        return
      end

      flash[:sv_inquiry] = {
        "store_credit_match_ids" => matches.map { |row| row.customer.id },
        "customer_query" => query
      }
      redirect_to pos_stored_value_inquiry_path(inquiry_register_params.merge(customer_query: query))
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
        flash[:sv_inquiry] = { "admin_gift_card_id" => result.card.id }
        redirect_to pos_stored_value_inquiry_path(inquiry_register_params)
      when :ambiguous
        flash[:sv_inquiry] = {
          "admin_candidate_ids" => result.candidates.map(&:id),
          "admin_prefix" => params[:number_prefix].to_s,
          "admin_last_four" => params[:number_last_four].to_s
        }
        redirect_to pos_stored_value_inquiry_path(inquiry_register_params),
                    alert: "Several cards share that prefix and last four. Choose a masked candidate."
      else
        redirect_to pos_stored_value_inquiry_path(inquiry_register_params),
                    alert: GiftCards::GENERIC_INQUIRY_FAILURE
      end
    rescue GiftCards::Error => e
      redirect_to pos_stored_value_inquiry_path(inquiry_register_params), alert: e.message
    end

    private

    def prepare_surface
      prepare_inquiry_shell!(surface: :stored_value_inquiry)
      @can_admin_inquire = Authorization::PermissionEvaluator.allowed?(
        user: current_user,
        permission_key: "gift_cards.view",
        store: current_store
      )
      @customer_query = params[:customer_query].to_s
    end

    def restore_inquiry_result!
      payload = flash[:sv_inquiry]
      return if payload.blank?

      if payload["exact_gift_card_id"].present?
        card = GiftCard.includes(:gift_card_program, :stored_value_account).find_by(id: payload["exact_gift_card_id"])
        return unless card

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
      end

      if payload["store_credit_match_ids"].present?
        ids = Array(payload["store_credit_match_ids"])
        customers = Customer.active.canonical.where(id: ids).index_by(&:id)
        @store_credit_matches = ids.filter_map do |id|
          customer = customers[id]
          next unless customer

          Customers::Search::Result.new(customer: customer, matched_former_customer: false)
        end
        @customer_query = payload["customer_query"].presence || @customer_query
      end

      if payload["store_credit_customer_id"].present?
        customer = Customer.active.canonical.find_by(id: payload["store_credit_customer_id"])
        if customer
          @store_credit_customer = customer
          @store_credit_account = customer.stored_value_accounts.find_by(account_type: "store_credit")
          @continuations = Pos::StoredValueInquiryContinuations.call(
            state: @state,
            actor: current_user,
            store: current_store,
            store_credit_customer: customer
          )
        end
      end

      if payload["admin_gift_card_id"].present?
        card = GiftCard.includes(:gift_card_program, :stored_value_account).find_by(id: payload["admin_gift_card_id"])
        if card
          @admin_card = card
          @admin_activity = StoredValue::AccountActivity.call(
            account: card.stored_value_account,
            actor: current_user,
            permission_key: "gift_cards.view",
            page: 1
          )
        end
      end

      if payload["admin_candidate_ids"].present?
        cards = GiftCard.includes(:gift_card_program, :stored_value_account)
                        .where(id: payload["admin_candidate_ids"])
                        .index_by(&:id)
        @admin_candidates = Array(payload["admin_candidate_ids"]).filter_map do |id|
          card = cards[id]
          next unless card

          GiftCards::AdminInquiry::Candidate.new(
            id: card.id,
            masked_number: card.masked_number,
            status: card.status,
            program_name: card.gift_card_program.name,
            balance_cents: card.balance_cents,
            activated_at: card.activated_at
          )
        end
      end
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
