# frozen_string_literal: true

module Pos
  class FreezeLinkedReturnLine
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(transaction:, line:)
      @transaction = transaction
      @line = line
    end

    def call
      original = @line.original_transaction_line
      raise Pos::Error, "linked return is missing the original sale line" if original.nil?
      raise Pos::Error, "original line is not a completed sale" unless original.sale? && original.pos_transaction.completed?
      raise Pos::Error, "original sale is not at this store" unless original.pos_transaction.store_id == @transaction.store_id

      remaining = Pos::Returnability.remaining_quantity(original)
      raise Pos::Error, "return quantity exceeds remaining quantity" if @line.quantity > remaining

      freeze_unit!(original)

      allocation = Pos::HistoricalReturnAllocation.call(
        original_line: original,
        requested_quantity: @line.quantity
      )
      @line.reference_unit_price_cents = original.reference_unit_price_cents
      @line.selling_unit_price_cents = original.selling_unit_price_cents
      @line.extended_selling_amount_cents = allocation.extended_selling_amount_cents
      @line.manual_discount_basis_points = original.manual_discount_basis_points
      @line.manual_discount_cents = allocation.manual_discount_cents
      @line.net_merchandise_amount_cents = allocation.net_merchandise_amount_cents
      @line.line_tax_cents = allocation.line_tax_cents
      @line.line_total_cents = allocation.line_total_cents
      @line.tax_class_id = original.tax_class_id
      @line.tax_class_code_snapshot = original.tax_class_code_snapshot
      @line.tax_class_name_snapshot = original.tax_class_name_snapshot
      @line.default_tax_class_id = original.default_tax_class_id
      @line.default_tax_class_code_snapshot = original.default_tax_class_code_snapshot
      @line.default_tax_class_name_snapshot = original.default_tax_class_name_snapshot
      @line.merchandise_snapshot = original.merchandise_snapshot.deep_dup
      @line.save!

      @line.pos_line_tax_components.delete_all
      allocation.components.each do |component|
        @line.pos_line_tax_components.create!(
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
      @line
    end

    private

    def freeze_unit!(original)
      if original.inventory_unit_id.present?
        raise Pos::Error, "inventory unit is required" if @line.inventory_unit_id.blank?
        raise Pos::Error, "quantity must be 1 for individually tracked merchandise" unless @line.quantity == 1
        raise Pos::Error, "return unit does not match the original sale" unless @line.inventory_unit_id == original.inventory_unit_id

        unit = InventoryUnit.find(@line.inventory_unit_id)
        raise Pos::Error, "unit is not returned from a completed sale" unless unit.removed?
        raise Pos::Error, "unit is not at this store" unless unit.store_id == @transaction.store_id
        raise Pos::Error, "unit does not match the merchandise" unless unit.product_variant_id == @line.product_variant_id
      else
        raise Pos::Error, "inventory unit must be blank" if @line.inventory_unit_id.present?
      end
    rescue ActiveRecord::RecordNotFound
      raise Pos::Error, "unit is not returned from a completed sale"
    end
  end
end
