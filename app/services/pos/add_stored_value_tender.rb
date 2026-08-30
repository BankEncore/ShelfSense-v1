# frozen_string_literal: true

module Pos
  class AddStoredValueTender
    Result = Data.define(
      :transaction,
      :tender,
      :operation,
      :requested_cents,
      :available_cents,
      :applied_cents,
      :remaining_due_cents,
      :capped,
      :replayed
    )

    # Validated placement of a working stored-value payment. Callers persist the
    # tender themselves so replacement can destroy the original in the same
    # transaction.
    Plan = Data.define(:account, :gift_card, :requested_cents, :available_cents, :applied_cents, :remaining_due_cents) do
      def capped?
        applied_cents < requested_cents
      end
    end

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      transaction:,
      actor:,
      expected_lock_version:,
      tender_type:,
      amount_cents:,
      operation_id:,
      card_number: nil,
      stored_value_account: nil
    )
      @transaction = transaction
      @actor = actor
      @expected_lock_version = expected_lock_version
      @tender_type = tender_type
      @amount_cents = amount_cents.to_i
      @operation_id = operation_id
      @card_number = card_number.to_s.strip.presence
      @stored_value_account = stored_value_account
    end

    def call
      lease = nil
      Pos::Support.authorize!(@actor, @transaction.store)
      Pos::Support.require_active_context!(@transaction.store, @transaction.register)
      Pos::Support.require_transaction_cashier!(@actor, @transaction)
      validate_request!

      lease = Pos::OperationLease.begin!(
        register_id: @transaction.register_id,
        operation_id: @operation_id,
        command_payload: command_payload,
        store_id: @transaction.store_id,
        pos_transaction_id: @transaction.id,
        command_type: PosOperation::ADD_WORKING_STORED_VALUE_TENDER_COMMAND_TYPE
      )
      return replay_result(lease.operation) if lease.replayed

      result = nil
      PosTransaction.transaction do
        operation = PosOperation.lock.find(lease.operation.id)
        transaction = Pos::Support.lock_working_transaction!(@transaction, @expected_lock_version)
        plan = plan!(transaction)
        tender = persist_tender!(transaction, plan, tender_number: Pos::Support.next_tender_number(transaction))
        Pos::Support.touch_working_transaction!(transaction)
        record_audit!(transaction, tender, plan)
        Pos::CompleteWorkingOperation.call(
          operation: operation,
          fact_type: PosOperation::ADD_WORKING_STORED_VALUE_TENDER_FACT_TYPE,
          facts: facts_for(tender, plan)
        )
        result = Result.new(
          transaction: transaction,
          tender: tender,
          operation: operation,
          requested_cents: plan.requested_cents,
          available_cents: plan.available_cents,
          applied_cents: plan.applied_cents,
          remaining_due_cents: plan.remaining_due_cents,
          capped: plan.capped?,
          replayed: false
        )
      end
      result
    rescue Pos::PayloadMismatch, Pos::OperationLease::Error
      raise
    rescue GiftCards::Error => e
      Pos::OperationLease.fail!(lease.operation) if lease&.operation&.reload&.status == "in_flight"
      raise Pos::Error, e.message
    rescue StandardError
      Pos::OperationLease.fail!(lease.operation) if lease&.operation&.reload&.status == "in_flight"
      raise
    end

    # Validates the full proposed placement against the locked transaction and
    # returns the capped plan. Raises rather than shrinking silently to zero.
    def plan!(transaction, except: nil)
      Pos::Support.require_commercial_content!(transaction)
      raise Pos::Error, "cannot redeem stored value on a ticket with gift-card issuance" if transaction.pos_stored_value_issuances.any?
      raise Pos::Error, "transaction does not require payment" unless Pos::Support.settlement_direction(transaction) == :payment

      remaining = Pos::Support.remaining_payment_cents(transaction, except: except)
      raise Pos::Error, "no remaining amount due" if remaining <= 0
      raise Pos::Error, "amount is greater than remaining due" if @amount_cents > remaining

      account = resolve_account!(transaction)
      if duplicate_account?(transaction, account, except: except)
        raise Pos::Error, "this stored-value account is already on the transaction"
      end

      available = account.balance_cents.to_i
      applied = [ @amount_cents, available ].min
      raise Pos::Error, "stored-value account has no available balance" unless applied.positive?

      Plan.new(
        account: account,
        gift_card: account.gift_card,
        requested_cents: @amount_cents,
        available_cents: available,
        applied_cents: applied,
        remaining_due_cents: remaining - applied
      )
    end

    def persist_tender!(transaction, plan, tender_number:)
      tender = transaction.pos_tenders.new(
        direction: "payment",
        tender_number: tender_number,
        amount_cents: plan.applied_cents,
        amount_presented_cents: nil,
        change_cents: nil
      )
      Pos::Support.snapshot_tender_identity!(tender, @tender_type)
      tender.save!
      tender.create_stored_value_tender_detail!(
        destination_mode: "existing_account",
        stored_value_account: plan.account,
        gift_card: plan.gift_card,
        masked_card_snapshot: plan.gift_card&.masked_number
      )
      tender
    end

    private

    def validate_request!
      raise Pos::Error, "tender is not available" unless @tender_type.active?
      raise Pos::Error, "tender is not stored value" unless @tender_type.stored_value?
      raise Pos::Error, "amount must be positive" unless @amount_cents.positive?
    end

    # Never carries a full card number; only a keyed digest and last four.
    def command_payload
      {
        transaction_id: @transaction.id,
        expected_lock_version: @expected_lock_version.to_i,
        tender_type_id: @tender_type.id,
        tender_type_code: @tender_type.code,
        requested_amount_cents: @amount_cents,
        destination_mode: "existing_account",
        customer_id: @transaction.customer_id,
        card_number_digest: card_number_digest,
        card_last_four: card_last_four
      }
    end

    def normalized_card_number
      return if @card_number.blank?

      @normalized_card_number ||= GiftCards::Number.normalize(@card_number)
    end

    def card_number_digest
      return if normalized_card_number.blank?

      GiftCards::Number.digest(normalized_card_number)
    end

    def card_last_four
      GiftCards::Number.last_four(normalized_card_number)
    end

    def facts_for(tender, plan)
      {
        tender_id: tender.id,
        stored_value_account_id: plan.account.id,
        masked_card_snapshot: plan.gift_card&.masked_number,
        requested_cents: plan.requested_cents,
        available_cents: plan.available_cents,
        applied_cents: plan.applied_cents,
        remaining_due_cents: plan.remaining_due_cents,
        capped: plan.capped?
      }
    end

    def record_audit!(transaction, tender, plan)
      Audit::Recorder.record!(
        action: "pos.working_stored_value_tender.added",
        outcome: "succeeded",
        actor_user: @actor,
        actor_label: @actor.display_name,
        store: transaction.store,
        register: transaction.register,
        subject: tender,
        after_values: tender.slice(
          "id", "tender_number", "tender_type", "tender_name", "behavioral_category",
          "direction", "amount_cents"
        ),
        metadata: {
          requested_cents: plan.requested_cents,
          available_cents: plan.available_cents,
          applied_cents: plan.applied_cents,
          capped: plan.capped?,
          stored_value_account_id: plan.account.id,
          masked_card_snapshot: plan.gift_card&.masked_number
        }.compact
      )
    end

    def resolve_account!(transaction)
      return reuse_account!(transaction) if @stored_value_account

      case @tender_type.stored_value_account_type
      when "gift_card"
        raise Pos::Error, "a card number is required" if @card_number.blank?

        card = GiftCards::Lookup.by_number(@card_number)
        raise Pos::Error, "gift card is not available" unless card&.active?

        card.stored_value_account
      when "store_credit", "trade_credit"
        customer = transaction.customer
        raise Pos::Error, "a customer is required" if customer.blank?
        raise Pos::Error, "customer must be an active canonical customer" unless customer.canonical? && customer.active?

        account = StoredValueAccount.where(customer_id: customer.id, account_type: @tender_type.stored_value_account_type)
                                    .where.not(status: "closed").order(:id).first
        raise Pos::Error, "customer stored-value account is not available" unless account&.active?

        account
      else
        raise Pos::Error, "tender is not stored value"
      end
    end

    def reuse_account!(transaction)
      account = StoredValueAccount.find(@stored_value_account.id)
      raise Pos::Error, "stored-value account is not available" unless account.active?
      if @tender_type.stored_value_account_type.in?(%w[store_credit trade_credit])
        raise Pos::Error, "a customer is required" if transaction.customer.blank?
        unless account.customer_id == transaction.customer_id
          raise Pos::Error, "stored-value account does not belong to this customer"
        end
      end

      account
    end

    def duplicate_account?(transaction, account, except: nil)
      transaction.pos_tenders.payments.reject { |tender| except && tender.id == except.id }.any? { |tender|
        tender.stored_value_tender_detail&.stored_value_account_id == account.id
      }
    end

    def replay_result(operation)
      facts = operation.envelope.fetch("facts", {})
      Result.new(
        transaction: operation.pos_transaction,
        tender: PosTender.find_by(id: facts["tender_id"]),
        operation: operation,
        requested_cents: facts["requested_cents"],
        available_cents: facts["available_cents"],
        applied_cents: facts["applied_cents"],
        remaining_due_cents: facts["remaining_due_cents"],
        capped: facts["capped"],
        replayed: true
      )
    end
  end
end
