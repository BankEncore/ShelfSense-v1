# frozen_string_literal: true

module Pos
  class ChangeQuantity
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(transaction:, line:, actor:, expected_lock_version:, quantity:)
      @transaction = transaction
      @line = line
      @actor = actor
      @expected_lock_version = expected_lock_version
      @quantity = quantity.to_i
    end

    def call
      Pos::Support.authorize!(@actor, @transaction.store)
      Pos::Support.require_active_context!(@transaction.store, @transaction.register)
      Pos::Support.require_transaction_cashier!(@actor, @transaction)
      raise Pos::Error, "quantity must be positive" unless @quantity.positive?
      raise Pos::Error, "line does not belong to transaction" unless @line.pos_transaction_id == @transaction.id

      PosTransaction.transaction do
        transaction = Pos::Support.lock_working_transaction!(@transaction, @expected_lock_version)
        Pos::Support.clear_working_tenders!(transaction)
        line = transaction.pos_transaction_lines.find(@line.id)
        raise Pos::Error, "quantity must be 1 for individually tracked merchandise" if line.unit_line? && @quantity != 1
        line.quantity = @quantity
        line.recalc_extended!
        Pos::Support.apply_provisional_tax!(line)
        line.save!
        Pos::Support.refresh_totals!(transaction)
        line
      end
    rescue Pos::Tax::UnresolvedApplicability => e
      raise Pos::Error, e.message
    end
  end
end
