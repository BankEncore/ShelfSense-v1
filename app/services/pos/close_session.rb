# frozen_string_literal: true

module Pos
  class CloseSession
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      session:,
      actor:,
      expected_lock_version:,
      closing_count_cents:,
      variance_reason_code: nil,
      variance_notes: nil,
      close_reason_code: nil,
      approver_username: nil,
      approver_password: nil,
      approved_by: nil
    )
      @session = session
      @actor = actor
      @expected_lock_version = expected_lock_version
      @closing_count_cents = closing_count_cents
      @variance_reason_code = variance_reason_code.to_s.strip.presence
      @variance_notes = variance_notes.to_s.strip.presence
      @close_reason_code = close_reason_code.to_s.strip.presence
      @approver_username = approver_username
      @approver_password = approver_password
      @approved_by = approved_by
    end

    def call
      count_cents = Pos::Support.parse_nonnegative_cents!(@closing_count_cents, "closing count")

      PosSession.transaction do
        preview = PosSession.find(@session.id)
        store = preview.store
        Cash::Locations.ensure!(store)
        # Safe before session matches OpenSession / Cash::Post (locations then sessions).
        safe = CashLocation.lock.find_by!(store: store, location_type: "safe")
        session = PosSession.lock.find(@session.id)
        store = session.store
        Pos::Support.require_active_context!(store, session.register)
        authorize_closer!(session, store)
        raise Pos::Error, "session is not open" unless session.open?
        if session.lock_version != @expected_lock_version.to_i
          raise Pos::StaleObject, "stale lock_version"
        end
        if session.pos_transactions.working.exists?
          raise Pos::Error, "session has a working transaction"
        end

        assisted = @actor.id != session.cashier_user_id
        if assisted && @close_reason_code.blank?
          raise Pos::Error, "a reason is required to close another cashier's session"
        end

        expected_cents = Pos::SessionTotals.for(session).expected_cash_cents
        variance_cents = count_cents - expected_cents
        approved_by = nil

        if variance_cents != 0
          kind = variance_cents.positive? ? "over" : "short"
          reason = Cash::ActivityReasons.require!(@variance_reason_code, kind)
          if reason.notes_required && @variance_notes.blank?
            raise Pos::Error, "variance notes are required"
          end
          abs_variance = variance_cents.abs
          if abs_variance >= Cash::Thresholds.note_cents(store) && @variance_notes.blank?
            raise Pos::Error, "a note is required for this variance"
          end
          if abs_variance >= Cash::Thresholds.approval_cents(store)
            approved_by = resolve_variance_approver!(session, store)
          end
        end

        session.update!(
          status: "closed",
          closed_at: Time.current,
          closed_by_user_id: @actor.id,
          close_reason_code: assisted ? @close_reason_code : nil,
          close_reason_name_snapshot: assisted ? "Manager-assisted close" : nil,
          closing_expected_cash_cents: expected_cents,
          closing_count_cents: count_cents,
          closing_variance_cents: variance_cents
        )

        count_record = CashCount.create!(
          purpose: "session_close",
          total_cents: count_cents,
          pos_session: session,
          status: "accepted"
        )

        if variance_cents != 0
          reason = Cash::ActivityReasons.require!(@variance_reason_code, variance_cents.positive? ? "over" : "short")
          recon_operation = Cash::Post.call(
            operation_type: "reconcile",
            store: store,
            performed_by: @actor,
            approved_by: approved_by,
            pos_session: session,
            source_id: SecureRandom.uuid_v7,
            idempotency_key: SecureRandom.uuid_v7,
            reason_code: reason.code,
            reason_name_snapshot: reason.name,
            notes: @variance_notes,
            entries: [ {
              pos_session: session,
              amount_cents: variance_cents,
              balance_after_cents: count_cents
            } ]
          )
          CashReconciliation.create!(
            direction: variance_cents.positive? ? "over" : "short",
            expected_cents: expected_cents,
            counted_cents: count_cents,
            variance_cents: variance_cents,
            pos_session: session,
            cash_count: count_record,
            cash_operation: recon_operation
          )
        end

        if count_cents.positive?
          transfer_operation = Cash::Post.call(
            operation_type: "transfer",
            store: store,
            performed_by: @actor,
            pos_session: session,
            source_id: SecureRandom.uuid_v7,
            idempotency_key: SecureRandom.uuid_v7,
            entries: [
              { pos_session: session, amount_cents: -count_cents, balance_after_cents: 0 },
              { cash_location: safe, amount_cents: count_cents }
            ]
          )
          CashTransfer.create!(
            transfer_type: "session_close",
            amount_cents: count_cents,
            source_pos_session: session,
            destination_cash_location: safe,
            cash_operation: transfer_operation
          )
        end

        Audit::Recorder.record!(
          action: "pos.session.closed",
          outcome: "succeeded",
          actor_user: @actor,
          actor_label: @actor.display_name,
          store: store,
          register: session.register,
          subject: session,
          after_values: {
            closing_count_cents: session.closing_count_cents,
            closing_expected_cash_cents: session.closing_expected_cash_cents,
            closing_variance_cents: session.closing_variance_cents,
            closed_by_user_id: session.closed_by_user_id,
            cashier_user_id: session.cashier_user_id
          }
        )
        session
      end
    rescue Cash::Error => e
      raise Pos::Error, e.message
    end

    private

    def authorize_closer!(session, store)
      if @actor.id == session.cashier_user_id
        Pos::Support.authorize!(@actor, store)
        return
      end

      unless Authorization::PermissionEvaluator.allowed?(
        user: @actor,
        permission_key: "pos.sessions.close_for_other",
        store: store
      )
        raise Pos::Denied, "not authorized to close another cashier's session"
      end
    end

    def resolve_variance_approver!(session, store)
      if Authorization::PermissionEvaluator.allowed?(
        user: @actor, permission_key: "cash.approve_variance", store: store
      )
        return nil
      end

      return @approved_by if @approved_by.present? && @approved_by.id != @actor.id

      Pos::AuthenticateApprover.call(
        username: @approver_username,
        password: @approver_password,
        store: store,
        action_type: "cash_variance",
        performer: @actor,
        permission_key: "cash.approve_variance"
      )
    end
  end
end
