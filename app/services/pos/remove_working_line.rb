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
        transaction.pos_transaction_lines.find(@line.id).destroy!
        Pos::Support.refresh_totals!(transaction)
        transaction
      end
    end
  end
end
