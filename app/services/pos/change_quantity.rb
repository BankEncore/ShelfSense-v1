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
        if line.sale? && (line.price_overridden? || line.manually_discounted?)
          raise Pos::Error, "Remove the price override or discount before changing quantity."
        end
        if line.return? && !line.linked_return?
          raise Pos::Error, "unlinked returns cannot change quantity"
        end
        if line.linked_return?
          apply_linked_quantity!(transaction, line)
        else
          line.quantity = @quantity
          line.recalc_extended!
          Pos::Support.apply_provisional_tax!(line)
          line.save!
        end
        Pos::Support.refresh_totals!(transaction)
        Pos::Support.touch_working_transaction!(transaction)
        line.reload
      end
    rescue Pos::Tax::UnresolvedApplicability => e
      raise Pos::Error, e.message
    end

    private

    def apply_linked_quantity!(_transaction, line)
      original = line.original_transaction_line
      remaining = Pos::Returnability.remaining_quantity(original)
      raise Pos::Error, "return quantity exceeds remaining quantity" if @quantity > remaining

      allocation = Pos::HistoricalReturnAllocation.call(original_line: original, requested_quantity: @quantity)
      line.quantity = allocation.quantity
      line.extended_selling_amount_cents = allocation.extended_selling_amount_cents
      line.manual_discount_cents = allocation.manual_discount_cents
      line.net_merchandise_amount_cents = allocation.net_merchandise_amount_cents
      line.line_tax_cents = allocation.line_tax_cents
      line.line_total_cents = allocation.line_total_cents
      line.save!
      line.pos_line_tax_components.delete_all
      allocation.components.each do |component|
        line.pos_line_tax_components.create!(
          store_tax_id: component.store_tax_id,
          store_tax_code_snapshot: component.store_tax_code_snapshot,
          store_tax_name_snapshot: component.store_tax_name_snapshot,
          rate_percent: component.rate_percent,
          applies: component.applies,
          taxable_basis_cents: component.taxable_basis_cents,
          tax_cents: component.tax_cents,
          calculation_order: component.calculation_order
        )
      end
    end
  end
end
