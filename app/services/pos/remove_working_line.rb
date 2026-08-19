# frozen_string_literal: true

module Pos
  class RemoveWorkingLine
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(transaction:, line:, actor:, expected_lock_version:)
      @transaction = transaction
      @line = line
      @actor = actor
      @expected_lock_version = expected_lock_version
    end

    def call
      Pos::Support.authorize!(@actor, @transaction.store)
      Pos::Support.require_active_context!(@transaction.store, @transaction.register)
      Pos::Support.require_transaction_cashier!(@actor, @transaction)
      raise Pos::Error, "line does not belong to transaction" unless @line.pos_transaction_id == @transaction.id

      PosTransaction.transaction do
        transaction = Pos::Support.lock_working_transaction!(@transaction, @expected_lock_version)
        Pos::Support.clear_working_tenders!(transaction)
        transaction.pos_transaction_lines.find(@line.id).tap do |line|
          record_linked_return_removed!(transaction, line) if line.linked_return?
          line.destroy!
        end
        Pos::Support.refresh_totals!(transaction)
        transaction
      end
    end

    private

    def record_linked_return_removed!(transaction, line)
      Audit::Recorder.record!(
        action: "pos.linked_return.removed",
        outcome: "succeeded",
        actor_user: @actor,
        actor_label: @actor.display_name,
        store: transaction.store,
        register: transaction.register,
        subject: line,
        before_values: {
          original_transaction_line_id: line.original_transaction_line_id,
          quantity: line.quantity
        }
      )
    end
  end
end
