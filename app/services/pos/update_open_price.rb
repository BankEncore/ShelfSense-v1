# frozen_string_literal: true

module Pos
  class UpdateOpenPrice
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(transaction:, line:, actor:, expected_lock_version:, selling_price_cents:)
      @transaction = transaction
      @line = line
      @actor = actor
      @expected_lock_version = expected_lock_version
      @selling_price_cents = selling_price_cents
    end

    def call
      Pos::Support.authorize!(@actor, @transaction.store)
      Pos::Support.require_active_context!(@transaction.store, @transaction.register)
      Pos::Support.require_transaction_cashier!(@actor, @transaction)
      raise Pos::Error, "selling price is required" if @selling_price_cents.nil?
      raise Pos::Error, "selling price cannot be negative" if @selling_price_cents.negative?

      PosTransaction.transaction do
        transaction = Pos::Support.lock_working_transaction!(@transaction, @expected_lock_version)
        line = transaction.pos_transaction_lines.find(@line.id)
        raise Pos::Error, "open-price edit is only available on sale lines" unless line.sale?
        raise Pos::Error, "open-price edit is not available on a return line" if line.return?
        unless line.pricing_method_snapshot == "open_price"
          raise Pos::Error, "this line is not an open-price line"
        end
        if line.manually_discounted?
          raise Pos::Error, "Remove the line discount before changing the price."
        end

        Pos::Support.clear_working_tenders!(transaction)
        line.reference_unit_price_cents = @selling_price_cents
        line.selling_unit_price_cents = @selling_price_cents
        line.recalc_extended!
        Pos::Support.apply_provisional_tax!(line)
        line.save!
        Pos::Support.refresh_totals!(transaction)
        Pos::Support.touch_working_transaction!(transaction)
        line
      end
    end
  end
end
