# frozen_string_literal: true

module Pos
  class CompleteStoredValue
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(transaction:, actor:, operation:)
      @transaction = transaction
      @actor = actor
      @operation = operation
    end

    def call
      issuances = @transaction.pos_stored_value_issuances.ordered.to_a
      tenders = stored_value_tenders
      if issuances.any? && tenders.any? { |tender| tender.direction == "payment" }
        raise Pos::Error, "cannot activate or reload and redeem stored value on the same transaction"
      end

      require_customer!(tenders)
      Pos::StoredValueRefundCapacity.assert_working_allocation!(@transaction)
      issuances.each { |issuance| attributed(issuance_id: issuance.id) { post_issuance!(issuance) } }
      tenders.each { |tender| attributed(tender_id: tender.id) { post_tender!(tender) } }
    rescue StoredValue::Error, GiftCards::Error => e
      raise Pos::Error, e.message
    end

    private

    # Completion-time revalidation must identify the working record that refused
    # so Tender Review can select it instead of clearing anything.
    def attributed(tender_id: nil, issuance_id: nil)
      yield
    rescue Pos::StoredValueCompletionFailure
      raise
    rescue Pos::Error, StoredValue::Error, GiftCards::Error => e
      raise Pos::StoredValueCompletionFailure.new(e.message, tender_id: tender_id, issuance_id: issuance_id)
    end

    def stored_value_tenders
      @transaction.pos_tenders.ordered.select(&:stored_value?)
    end

    def require_customer!(tenders)
      needs_customer = tenders.any? { |tender|
        type = tender.configured_tender_type
        next false unless type&.stored_value?

        type.stored_value_account_type.in?(%w[store_credit trade_credit]) ||
          tender.stored_value_tender_detail&.customer_store_credit?
      }
      return unless needs_customer

      dependent_tender_id = tenders.find { |tender|
        type = tender.configured_tender_type
        type&.stored_value_account_type.in?(%w[store_credit trade_credit]) ||
          tender.stored_value_tender_detail&.customer_store_credit?
      }&.id
      customer = @transaction.customer
      if customer.blank?
        raise Pos::StoredValueCompletionFailure.new("a customer is required", tender_id: dependent_tender_id)
      end
      return if customer.canonical? && customer.active?

      raise Pos::StoredValueCompletionFailure.new(
        "customer must be an active canonical customer",
        tender_id: dependent_tender_id
      )
    end

    def post_issuance!(issuance)
      return if issuance.stored_value_operation_id.present?

      card = if issuance.reload_issuance?
        issuance.gift_card
      else
        provision_activation_card!(issuance)
      end
      raise Pos::Error, "gift card is not available" unless card&.active?

      operation = StoredValue::Post.call(
        operation_type: issuance.issuance_type == "reload" ? "reload" : "activate",
        store: @transaction.store,
        performed_by: @actor,
        source_id: @operation.id,
        idempotency_key: Pos::Support.nested_stored_value_idempotency_key(@operation.id, "issuance", issuance.id),
        pos_session: @transaction.pos_session,
        business_date: @transaction.reporting_period.business_date,
        entries: [ { account: card.stored_value_account, amount_cents: issuance.amount_cents } ]
      )
      issuance.update!(
        gift_card: card,
        stored_value_operation: operation,
        masked_card_snapshot: card.masked_number,
        pending_card_number: nil,
        pending_card_number_digest: nil,
        pending_card_number_prefix: nil,
        pending_card_number_last_four: nil
      )
    end

    def provision_activation_card!(issuance)
      program = issuance.gift_card_program
      raise Pos::Error, "gift-card program is required" if program.blank?

      number = if program.system_generated?
        nil
      else
        issuance.pending_card_number
      end
      GiftCards::ProvisionInstrument.call(
        program: program,
        store: @transaction.store,
        number: number,
        customer: @transaction.customer
      )
    end

    def post_tender!(tender)
      detail = tender.stored_value_tender_detail
      raise Pos::Error, "stored-value tender is missing its detail" if detail.blank?
      return if detail.stored_value_operation_id.present?

      account = resolve_tender_account!(tender, detail)
      amount = tender.direction == "payment" ? -tender.amount_cents : tender.amount_cents
      if tender.direction == "payment" && account.balance_cents < tender.amount_cents
        raise Pos::Error, "stored-value balance is insufficient"
      end

      operation = StoredValue::Post.call(
        operation_type: tender.direction == "payment" ? "redeem" : "refund",
        store: @transaction.store,
        performed_by: @actor,
        source_id: @operation.id,
        idempotency_key: Pos::Support.nested_stored_value_idempotency_key(@operation.id, "tender", tender.id),
        pos_session: @transaction.pos_session,
        business_date: @transaction.reporting_period.business_date,
        entries: [ { account: account, amount_cents: amount } ]
      )
      card = detail.gift_card || account.gift_card
      detail.update!(
        stored_value_operation: operation,
        stored_value_account: account,
        gift_card: card,
        masked_card_snapshot: card&.masked_number || detail.masked_card_snapshot,
        pending_card_number: nil,
        pending_card_number_digest: nil,
        pending_card_number_prefix: nil,
        pending_card_number_last_four: nil
      )
    end

    def resolve_tender_account!(tender, detail)
      if detail.new_gift_card?
        card = provision_refund_card!(detail)
        detail.gift_card = card
        return card.stored_value_account
      end
      if detail.customer_store_credit?
        return StoredValue::EnsureCustomerAccount.call(customer: @transaction.customer, account_type: "store_credit")
      end

      account = detail.stored_value_account
      raise Pos::Error, "stored-value account is required" if account.blank?
      if tender.configured_tender_type.stored_value_account_type.in?(%w[store_credit trade_credit])
        unless account.customer_id == @transaction.customer_id
          raise Pos::Error, "stored-value account does not belong to this customer"
        end
      end
      raise Pos::Error, "stored-value account is not available" unless account.active?

      account
    end

    def provision_refund_card!(detail)
      program = detail.gift_card_program
      raise Pos::Error, "gift-card program is required" if program.blank?

      GiftCards::ProvisionInstrument.call(
        program: program,
        store: @transaction.store,
        number: program.manual_external? ? detail.pending_card_number : nil,
        customer: @transaction.customer
      )
    end
  end
end
