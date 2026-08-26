# frozen_string_literal: true

module GiftCards
  class CashOut
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      gift_card:,
      session:,
      actor:,
      source_id:,
      idempotency_key:,
      customer_requested: false,
      approver_username: nil,
      approver_password: nil,
      reason_code: "gift_card_cash_out",
      reason_note: nil
    )
      @gift_card = gift_card
      @session = session
      @actor = actor
      @source_id = source_id
      @idempotency_key = idempotency_key
      @customer_requested = ActiveModel::Type::Boolean.new.cast(customer_requested)
      @approver_username = approver_username
      @approver_password = approver_password
      @reason_code = reason_code.to_s
      @reason_note = reason_note.to_s.strip.presence
    end

    def call
      unless Authorization::PermissionEvaluator.allowed?(
        user: @actor,
        permission_key: "gift_cards.cash_out",
        store: @session.store
      )
        raise GiftCards::Error, "not authorized to cash out gift cards"
      end
      raise GiftCards::Error, "session is not open" unless @session.open?
      working = @session.pos_transactions.working.first
      if working && Pos::Support.commercial_content?(working)
        raise GiftCards::Error, "complete or cancel the current transaction before cash-out"
      end

      eligibility = CashOutEligibility.call(@gift_card)
      raise GiftCards::Error, eligibility.reason unless eligibility.eligible
      if eligibility.requires_request_confirmation && !@customer_requested
        raise GiftCards::Error, "cash-out requires confirmation that the customer requested it"
      end

      payload = { gift_card_id: @gift_card.id, amount_cents: eligibility.amount_cents }
      op = Idempotency::OperationService.begin!(
        source_id: @source_id,
        operation_type: "gift_card_cash_out",
        idempotency_key: @idempotency_key,
        payload: payload
      )
      if op.replayed
        return GiftCardCashOut.find(op.operation.result_id) if op.operation.result_id

        raise GiftCards::Error, "idempotent replay missing result"
      end

      begin
        result = nil
        GiftCard.transaction do
          session = PosSession.lock.find(@session.id)
          Pos::Support.require_active_context!(session.store, session.register)
          Pos::Support.require_session_cashier!(@actor, session)
          raise GiftCards::Error, "session is not open" unless session.open?
          card = GiftCard.lock.find(@gift_card.id)
          account = StoredValueAccount.lock.find(card.stored_value_account_id)
          eligibility = CashOutEligibility.call(card)
          raise GiftCards::Error, eligibility.reason unless eligibility.eligible
          if eligibility.requires_request_confirmation && !@customer_requested
            raise GiftCards::Error, "cash-out requires confirmation that the customer requested it"
          end

          amount = eligibility.amount_cents
          begin
            Cash::AvailableCash.assert!(session, amount)
          rescue Cash::Error => e
            raise GiftCards::Error, e.message
          end
          approver = authenticate_approver!(session) if eligibility.approval_required
          cash_out_id = SecureRandom.uuid_v7
          occurred_at = Time.current
          operation = StoredValue::Post.call(
            operation_type: "cash_out",
            store: session.store,
            performed_by: @actor,
            source_id: cash_out_id,
            idempotency_key: Pos::Support.nested_stored_value_idempotency_key(cash_out_id, "cash_out", card.id),
            entries: [ { account: account, amount_cents: -amount } ],
            business_date: session.reporting_period.business_date,
            occurred_at: occurred_at,
            pos_session: session,
            reason_code: @reason_code,
            reason_name_snapshot: "Gift-card cash-out"
          )
          account.reload.close_zero!(at: occurred_at)
          card.update!(status: "closed", closed_at: occurred_at)

          cash_out = GiftCardCashOut.create!(
            id: cash_out_id,
            gift_card: card,
            stored_value_account: account,
            amount_cents: amount,
            register: session.register,
            pos_session: session,
            store: session.store,
            business_date: session.reporting_period.business_date,
            program_policy_snapshot: policy_snapshot(card.gift_card_program),
            performed_by: @actor,
            approved_by: approver,
            stored_value_operation: operation,
            posted_at: occurred_at
          )
          record_controlled_action!(cash_out, eligibility, approver)
          Audit::Recorder.record!(
            action: "gift_cards.cash_out",
            outcome: "succeeded",
            actor_user: @actor,
            store: session.store,
            register: session.register,
            subject: cash_out,
            after_values: {
              gift_card_id: card.id,
              amount_cents: amount,
              number_last_four: card.number_last_four
            }
          )
          Idempotency::OperationService.complete!(
            op.operation,
            result_type: "GiftCardCashOut",
            result_id: cash_out.id
          )
          result = cash_out
        end
        result
      rescue GiftCards::Error, Pos::Denied, StoredValue::Error, ActiveRecord::RecordInvalid => e
        Idempotency::OperationService.fail!(op.operation, message: e.message)
        raise GiftCards::Error, e.message
      end
    end

    private

    def authenticate_approver!(session)
      Pos::AuthenticateApprover.call(
        username: @approver_username,
        password: @approver_password,
        store: session.store,
        action_type: "gift_card_cash_out",
        performer: @actor,
        permission_key: "gift_cards.cash_out"
      )
    rescue Pos::Denied => e
      Audit::Recorder.record!(
        action: "gift_cards.cash_out",
        outcome: "denied",
        actor_user: @actor,
        store: session.store,
        register: session.register,
        subject: @gift_card,
        reason_code: "approval_denied",
        metadata: { message: e.message }
      )
      raise GiftCards::Error, e.message
    end

    def record_controlled_action!(cash_out, eligibility, approver)
      policy = eligibility.approval_required ? "approval_required" : "direct"
      material = {
        "gift_card_id" => cash_out.gift_card_id.to_s,
        "amount_cents" => cash_out.amount_cents,
        "pos_session_id" => cash_out.pos_session_id.to_s
      }
      fingerprint = Pos::ControlledActionFingerprint.call(
        action_type: "gift_card_cash_out",
        cash_out_id: cash_out.id,
        material_values: material,
        reason_code: @reason_code,
        reason_note: @reason_note
      )
      PosControlledAction.create!(
        action_type: "gift_card_cash_out",
        gift_card_cash_out: cash_out,
        performed_by_user: @actor,
        performed_by_name_snapshot: @actor.display_name,
        approved_by_user: approver,
        approved_by_name_snapshot: approver&.display_name,
        reason_code: @reason_code,
        reason_name_snapshot: "Gift-card cash-out",
        reason_note: @reason_note,
        policy_result: policy,
        policy_version: PosControlledAction::POLICY_VERSION,
        fingerprint_schema_version: PosControlledAction::FINGERPRINT_SCHEMA_VERSION,
        action_fingerprint: fingerprint,
        material_values: material,
        executed_at: cash_out.posted_at
      )
    end

    def policy_snapshot(program)
      {
        "cash_out_policy" => program.cash_out_policy,
        "cash_out_threshold_cents" => program.cash_out_threshold_cents,
        "cash_out_threshold_inclusive" => program.cash_out_threshold_inclusive,
        "cash_out_approval_required" => program.cash_out_approval_required
      }
    end
  end
end
