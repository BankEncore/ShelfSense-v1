# frozen_string_literal: true

module StoredValue
  class Adjust
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      account:,
      direction:,
      amount_cents:,
      reason:,
      store:,
      performed_by:,
      source_id:,
      idempotency_key:,
      approved_by: nil,
      customer_explanation: nil,
      internal_notes: nil,
      correlation_id: nil
    )
      @account = account
      @direction = direction.to_s
      @amount_cents = amount_cents
      @reason = reason
      @store = store
      @performed_by = performed_by
      @source_id = source_id
      @idempotency_key = idempotency_key
      @approved_by = approved_by
      @customer_explanation = customer_explanation
      @internal_notes = internal_notes
      @correlation_id = correlation_id || SecureRandom.uuid_v7
    end

    def call
      validate!
      payload = {
        stored_value_account_id: @account.id,
        direction: @direction,
        amount_cents: Integer(@amount_cents),
        reason_id: @reason.id
      }
      op = Idempotency::OperationService.begin!(
        source_id: @source_id,
        operation_type: "stored_value_adjust",
        idempotency_key: @idempotency_key,
        payload: payload
      )
      if op.replayed
        return StoredValueAdjustment.find(op.operation.result_id) if op.operation.result_id

        raise Error, "idempotent replay missing result"
      end

      begin
        result = nil
        StoredValueAccount.transaction do
          account = StoredValueAccount.lock.find(@account.id)
          validate_account!(account)
          signed = @direction == "credit" ? Integer(@amount_cents) : -Integer(@amount_cents)
          operation = Post.call(
            operation_type: "adjust",
            store: @store,
            performed_by: @performed_by,
            source_id: @source_id,
            idempotency_key: SecureRandom.uuid_v7,
            entries: [ { account: account, amount_cents: signed } ],
            reason_code: @reason.code,
            reason_name_snapshot: @reason.name,
            notes: @internal_notes,
            correlation_id: @correlation_id
          )
          adjustment = StoredValueAdjustment.create!(
            stored_value_account: account,
            adjustment_direction: @direction,
            amount_cents: Integer(@amount_cents),
            reason: @reason,
            reason_code: @reason.code,
            reason_name_snapshot: @reason.name,
            customer_explanation: @customer_explanation,
            internal_notes: @internal_notes,
            store: @store,
            performed_by: @performed_by,
            approved_by: @approved_by,
            stored_value_operation: operation,
            idempotency_operation: op.operation,
            posted_at: Time.current
          )
          Idempotency::OperationService.complete!(
            op.operation,
            result_type: "StoredValueAdjustment",
            result_id: adjustment.id
          )
          result = adjustment
        end
        result
      rescue Error, ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError => e
        Idempotency::OperationService.fail!(op.operation, message: e.message)
        Audit::Recorder.record!(
          action: "stored_value.adjust",
          outcome: "failed",
          actor_user: @performed_by,
          store: @store,
          subject: @account,
          correlation_id: @correlation_id,
          reason_text: e.message
        )
        raise Error, e.message
      rescue Idempotency::OperationService::PayloadMismatchError
        raise
      end
    end

    def self.second_user_required?(direction:, amount_cents:, reason:, account: nil)
      return true if direction.to_s == "debit"
      return true if reason.approval_required
      return true if account&.account_type == "gift_card" && account.gift_card&.suspended?

      threshold = SystemSettings.current.stored_value_adjust_credit_approval_threshold_cents
      Integer(amount_cents) >= threshold
    end

    private

    def validate!
      raise Error, "direction must be credit or debit" unless %w[credit debit].include?(@direction)
      raise Error, "amount must be positive" unless Integer(@amount_cents).positive?
      raise Error, "reason is required" if @reason.blank?
      raise Error, "reason is not allowed for this adjustment" unless @reason.active? && @reason.allows?(direction: @direction, account_type: @account.account_type)
      raise Error, "internal notes are required" if @reason.notes_required && @internal_notes.to_s.strip.blank?
      if self.class.second_user_required?(direction: @direction, amount_cents: @amount_cents, reason: @reason)
        raise Error, "second-user approval is required" if @approved_by.blank?
        raise Error, "approver cannot be the performer" if @approved_by.id == @performed_by.id
      end
    end

    def validate_account!(account)
      raise Error, "account is closed" if account.closed?
      if account.customer_owned?
        customer = account.customer
        raise Error, "inactive customers cannot receive new credit" if @direction == "credit" && !customer.active?
      elsif account.account_type == "gift_card"
        validate_gift_card!(account)
      end
    end

    def validate_gift_card!(account)
      card = account.gift_card
      raise Error, "gift-card instrument is missing" if card.blank?
      raise Error, "replaced gift cards cannot be adjusted" if card.replaced?
      raise Error, "closed gift cards cannot be adjusted" if card.closed?
      if card.suspended?
        raise Error, "second-user approval is required for suspended gift cards" if @approved_by.blank?
        raise Error, "approver cannot be the performer" if @approved_by.id == @performed_by.id
      end
      return unless @direction == "credit"

      maximum = card.gift_card_program.maximum_balance_cents
      return if maximum.blank?

      raise Error, "credit would exceed the program maximum balance" if account.balance_cents + Integer(@amount_cents) > maximum
    end
  end
end
