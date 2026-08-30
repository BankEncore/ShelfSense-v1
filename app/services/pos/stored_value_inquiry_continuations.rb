# frozen_string_literal: true

module Pos
  # Contextual continuation affordances for S14 exact-number and store-credit results.
  # Continuations link to existing workspace / cash-out flows; they do not mutate.
  class StoredValueInquiryContinuations
    Result = Struct.new(
      :can_tender,
      :can_reload,
      :can_cash_out,
      :cash_out_amount_cents,
      :workspace_path,
      :cash_out_path,
      keyword_init: true
    )

    def self.call(...)
      new(...).call
    end

    def initialize(state:, actor:, store:, gift_card: nil, store_credit_customer: nil)
      @state = state
      @actor = actor
      @store = store
      @gift_card = gift_card
      @store_credit_customer = store_credit_customer
    end

    def call
      own = @state.kind == "own_session" && @state.register.present?
      workspace = own ? Rails.application.routes.url_helpers.pos_register_workspace_path(register_id: @state.register.id) : nil
      working = working_transaction
      payment_due = working.present? && Pos::Support.remaining_payment_cents(working).positive?

      cash_out = cash_out_eligibility
      can_cash_out = own && cash_out&.eligible &&
                     Authorization::PermissionEvaluator.allowed?(
                       user: @actor,
                       permission_key: "gift_cards.cash_out",
                       store: @store
                     )

      Result.new(
        can_tender: own && payment_due && (@gift_card.present? || @store_credit_customer.present?),
        can_reload: own && @gift_card.present? && @gift_card.active?,
        can_cash_out: can_cash_out,
        cash_out_amount_cents: cash_out&.amount_cents,
        workspace_path: workspace,
        cash_out_path: can_cash_out ? Rails.application.routes.url_helpers.new_pos_cash_out_path : nil
      )
    end

    private

    def working_transaction
      session_record = @state.gate&.session
      return if session_record.blank?

      session_record.pos_transactions.working.first
    end

    def cash_out_eligibility
      return unless @gift_card

      GiftCards::CashOutEligibility.call(@gift_card)
    end
  end
end
