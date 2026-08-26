# frozen_string_literal: true

module Cash
  class Reverse
    FORBIDDEN_TYPES = %w[initialize_safe reconcile].freeze
    FORBIDDEN_TRANSFERS = %w[opening_float session_close].freeze

    def self.reversible?(operation)
      return false if operation.reverse? || operation.reversed?
      return false if FORBIDDEN_TYPES.include?(operation.operation_type)

      transfer = operation.cash_transfer
      return false if transfer && FORBIDDEN_TRANSFERS.include?(transfer.transfer_type)
      return false if transfer&.transfer_type == "deposit"

      session_ids = operation.cash_entries.filter_map(&:pos_session_id).uniq
      return true if session_ids.empty?

      session_ids.one? && PosSession.where(id: session_ids.first, status: "open").exists?
    end

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(operation:, actor:, source_id:, idempotency_key:, reason_code:, notes: nil)
      @operation = operation
      @actor = actor
      @source_id = source_id
      @idempotency_key = idempotency_key
      @reason_code = reason_code
      @notes = notes.to_s.strip.presence
    end

    def call
      unless Authorization::PermissionEvaluator.allowed?(
        user: @actor, permission_key: "cash.reverse", store: @operation.store
      )
        raise Error, "not authorized to reverse this cash operation"
      end
      raise Error, "operation is already a reverse" if @operation.reverse?
      raise Error, "operation has already been reversed" if @operation.reversed?
      raise Error, "this operation cannot be reversed" if FORBIDDEN_TYPES.include?(@operation.operation_type)

      transfer = @operation.cash_transfer
      if transfer && FORBIDDEN_TRANSFERS.include?(transfer.transfer_type)
        raise Error, "this operation cannot be reversed"
      end
      if transfer&.transfer_type == "deposit"
        raise Error, "deposit reversal is not available until deposit in transit is implemented"
      end

      reason = ActivityReasons.require!(@reason_code, "reverse")
      if reason.notes_required && @notes.blank?
        raise Error, "notes are required"
      end

      CashOperation.transaction do
        original = CashOperation.lock.find(@operation.id)
        raise Error, "operation has already been reversed" if original.reversed?

        entries = original.cash_entries.order(:entry_sequence).to_a
        Locations.ensure!(original.store)
        entries.filter_map(&:cash_location_id).uniq.sort.each do |location_id|
          CashLocation.lock.find(location_id)
        end
        session = lock_session_if_needed!(entries)

        inverse = entries.map { |entry| inverse_entry(entry, session) }
        Post.call(
          operation_type: "reverse",
          store: original.store,
          performed_by: @actor,
          pos_session: session,
          reversal_of: original,
          source_id: @source_id,
          idempotency_key: @idempotency_key,
          reason_code: reason.code,
          reason_name_snapshot: reason.name,
          notes: @notes,
          entries: inverse
        )
      end
    end

    private

    def lock_session_if_needed!(entries)
      session_ids = entries.filter_map(&:pos_session_id).uniq
      return if session_ids.empty?
      raise Error, "session-targeted reverse requires a single session" unless session_ids.one?

      session = SessionGuard.lock_open_session!(PosSession.find(session_ids.first))
      SessionGuard.refuse_commercial_working!(session)
      session
    end

    def inverse_entry(entry, session)
      amount = -entry.amount_cents
      if entry.pos_session_id.present?
        {
          pos_session: session,
          amount_cents: amount,
          balance_after_cents: SessionGuard.session_balance_after(session, amount),
          reversal_of: entry
        }
      else
        {
          cash_location: entry.cash_location,
          amount_cents: amount,
          reversal_of: entry
        }
      end
    end
  end
end
