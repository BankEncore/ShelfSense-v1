# frozen_string_literal: true

module GiftCards
  class ReverseCashOut
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      cash_out:,
      session:,
      actor:,
      source_id:,
      idempotency_key:,
      physical_cash_returned:,
      approver_username: nil,
      approver_password: nil
    )
      @cash_out = cash_out
      @session = session
      @actor = actor
      @source_id = source_id
      @idempotency_key = idempotency_key
      @physical_cash_returned = ActiveModel::Type::Boolean.new.cast(physical_cash_returned)
      @approver_username = approver_username
      @approver_password = approver_password
    end

    def call
      unless Authorization::PermissionEvaluator.allowed?(
        user: @actor,
        permission_key: "gift_cards.cash_out",
        store: @session.store
      )
        raise GiftCards::Error, "not authorized to reverse gift-card cash-out"
      end
      unless @physical_cash_returned
        raise GiftCards::Error, "reversal requires confirmation that the original cash has physically returned"
      end
      raise GiftCards::Error, "only an original cash-out can be reversed" if @cash_out.reversal?

      payload = { cash_out_id: @cash_out.id, pos_session_id: @session.id }
      op = Idempotency::OperationService.begin!(
        source_id: @source_id,
        operation_type: "gift_card_cash_out_reverse",
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
          original = GiftCardCashOut.lock.find(@cash_out.id)
          raise GiftCards::Error, "only an original cash-out can be reversed" if original.reversal?
          raise GiftCards::Error, "cash-out has already been reversed" if GiftCardCashOut.exists?(reversal_of_id: original.id)

          card = GiftCard.lock.find(original.gift_card_id)
          account = StoredValueAccount.lock.find(original.stored_value_account_id)
          raise GiftCards::Error, "gift-card account is not closed from this cash-out" unless account.closed? && account.balance_cents.zero?

          approver = nil
          if card.gift_card_program.cash_out_approval_required
            approver = Pos::AuthenticateApprover.call(
              username: @approver_username,
              password: @approver_password,
              store: session.store,
              action_type: "gift_card_cash_out",
              performer: @actor,
              permission_key: "gift_cards.cash_out"
            )
          end

          reversal_id = SecureRandom.uuid_v7
          occurred_at = Time.current
          original_entry = original.stored_value_operation.stored_value_entries.sole
          account.update!(status: "active", closed_at: nil)
          operation = StoredValue::Post.call(
            operation_type: "reverse",
            store: session.store,
            performed_by: @actor,
            source_id: reversal_id,
            idempotency_key: Pos::Support.nested_stored_value_idempotency_key(reversal_id, "reverse", original.id),
            entries: [ { account: account, amount_cents: original.amount_cents } ],
            business_date: session.reporting_period.business_date,
            occurred_at: occurred_at,
            pos_session: session,
            reversal_of: original.stored_value_operation,
            reversal_entry_map: { 0 => original_entry },
            reason_code: "gift_card_cash_out_reverse",
            reason_name_snapshot: "Gift-card cash-out reversal"
          )
          card.update!(status: "active", closed_at: nil)

          reversal = GiftCardCashOut.create!(
            id: reversal_id,
            gift_card: card,
            stored_value_account: account,
            amount_cents: original.amount_cents,
            register: session.register,
            pos_session: session,
            store: session.store,
            business_date: session.reporting_period.business_date,
            program_policy_snapshot: original.program_policy_snapshot,
            performed_by: @actor,
            approved_by: approver,
            stored_value_operation: operation,
            reversal_of: original,
            physical_cash_confirmed: true,
            physical_cash_confirmed_by: @actor,
            posted_at: occurred_at
          )
          Audit::Recorder.record!(
            action: "gift_cards.cash_out_reversed",
            outcome: "succeeded",
            actor_user: @actor,
            store: session.store,
            register: session.register,
            subject: reversal,
            after_values: {
              original_cash_out_id: original.id,
              amount_cents: original.amount_cents,
              number_last_four: card.number_last_four,
              physical_cash_confirmed: true
            }
          )
          Idempotency::OperationService.complete!(
            op.operation,
            result_type: "GiftCardCashOut",
            result_id: reversal.id
          )
          result = reversal
        end
        result
      rescue GiftCards::Error, Pos::Denied, StoredValue::Error, ActiveRecord::RecordInvalid => e
        Idempotency::OperationService.fail!(op.operation, message: e.message)
        raise GiftCards::Error, e.message
      end
    end
  end
end
