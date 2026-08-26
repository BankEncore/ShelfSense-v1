# frozen_string_literal: true

module Cash
  class PaidOut
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      session:,
      actor:,
      amount_cents:,
      reason_code:,
      source_id:,
      idempotency_key:,
      notes: nil,
      approver_username: nil,
      approver_password: nil
    )
      @session = session
      @actor = actor
      @amount_cents = amount_cents
      @reason_code = reason_code
      @notes = notes.to_s.strip.presence
      @source_id = source_id
      @idempotency_key = idempotency_key
      @approver_username = approver_username
      @approver_password = approver_password
    end

    def call
      amount = Integer(@amount_cents)
      raise Error, "amount must be positive" unless amount.positive?
      unless Authorization::PermissionEvaluator.allowed?(
        user: @actor, permission_key: "cash.paid_out", store: @session.store
      )
        raise Error, "not authorized to record a paid-out"
      end
      reason = ActivityReasons.require!(@reason_code, "paid_out")
      if reason.notes_required && @notes.blank?
        raise Error, "notes are required"
      end

      CashPaidOut.transaction do
        session = SessionGuard.lock_open_cashier_session!(@session, @actor)
        AvailableCash.assert!(session, amount)
        approved_by, policy = resolve_approver!(session, amount)
        operation = Post.call(
          operation_type: "paid_out",
          store: session.store,
          performed_by: @actor,
          approved_by: approved_by,
          pos_session: session,
          source_id: @source_id,
          idempotency_key: @idempotency_key,
          reason_code: reason.code,
          reason_name_snapshot: reason.name,
          notes: @notes,
          entries: [ {
            pos_session: session,
            amount_cents: -amount,
            balance_after_cents: SessionGuard.session_balance_after(session, -amount)
          } ]
        )
        return operation.cash_paid_out if operation.cash_paid_out

        paid_out = CashPaidOut.create!(
          pos_session: session,
          amount_cents: amount,
          reason_code: reason.code,
          reason_name_snapshot: reason.name,
          notes: @notes,
          cash_operation: operation
        )
        record_controlled_action!(paid_out, approved_by, policy, reason)
        paid_out
      end
    rescue Pos::Denied => e
      raise Error, e.message
    end

    private

    def resolve_approver!(session, amount)
      if amount < Thresholds.paid_out_cents(session.store)
        return [ nil, "direct" ]
      end

      if Authorization::PermissionEvaluator.allowed?(
        user: @actor, permission_key: "cash.approve_paid_out", store: session.store
      )
        return [ nil, "direct" ]
      end

      approver = Pos::AuthenticateApprover.call(
        username: @approver_username,
        password: @approver_password,
        store: session.store,
        action_type: "cash_paid_out",
        performer: @actor,
        permission_key: "cash.approve_paid_out"
      )
      [ approver, "approval_required" ]
    end

    def record_controlled_action!(paid_out, approver, policy, reason)
      material = {
        "cash_paid_out_id" => paid_out.id.to_s,
        "amount_cents" => paid_out.amount_cents,
        "pos_session_id" => paid_out.pos_session_id.to_s
      }
      fingerprint = Pos::ControlledActionFingerprint.call(
        action_type: "cash_paid_out",
        cash_paid_out_id: paid_out.id,
        material_values: material,
        reason_code: reason.code,
        reason_note: @notes
      )
      PosControlledAction.create!(
        action_type: "cash_paid_out",
        cash_paid_out: paid_out,
        performed_by_user: @actor,
        performed_by_name_snapshot: @actor.display_name,
        approved_by_user: approver,
        approved_by_name_snapshot: approver&.display_name,
        reason_code: reason.code,
        reason_name_snapshot: reason.name,
        reason_note: @notes,
        policy_result: policy,
        policy_version: PosControlledAction::POLICY_VERSION,
        fingerprint_schema_version: PosControlledAction::FINGERPRINT_SCHEMA_VERSION,
        action_fingerprint: fingerprint,
        material_values: material,
        executed_at: Time.current
      )
    end
  end
end
