# frozen_string_literal: true

module Pos
  class FreezePostVoidLine
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(transaction:, line:)
      @transaction = transaction
      @line = line
    end

    def call
      source = @line.post_void_source_line
      raise Pos::Error, "post-void line is missing the source line" if source.nil?
      raise Pos::Error, "post-void source line is not completed" unless source.pos_transaction.completed?
      raise Pos::Error, "post-void source is not at this store" unless source.pos_transaction.store_id == @transaction.store_id
      raise Pos::Error, "post-void line direction must reverse the source" unless opposite_direction?(source)
      raise Pos::Error, "post-void line quantity must match the source" unless @line.quantity == source.quantity
      raise Pos::Error, "post-void line merchandise must match the source" unless same_merchandise?(source)

      @line.reference_unit_price_cents = source.reference_unit_price_cents
      @line.selling_unit_price_cents = source.selling_unit_price_cents
      @line.extended_selling_amount_cents = source.extended_selling_amount_cents
      @line.manual_discount_basis_points = source.manual_discount_basis_points
      @line.manual_discount_cents = source.manual_discount_cents
      @line.net_merchandise_amount_cents = source.net_merchandise_amount_cents
      @line.line_tax_cents = source.line_tax_cents
      @line.line_total_cents = source.line_total_cents
      @line.tax_class_id = source.tax_class_id
      @line.tax_class_code_snapshot = source.tax_class_code_snapshot
      @line.tax_class_name_snapshot = source.tax_class_name_snapshot
      @line.default_tax_class_id = source.default_tax_class_id
      @line.default_tax_class_code_snapshot = source.default_tax_class_code_snapshot
      @line.default_tax_class_name_snapshot = source.default_tax_class_name_snapshot
      @line.merchandise_snapshot = source.merchandise_snapshot.deep_dup
      @line.save!

      @line.pos_line_tax_components.delete_all
      source.pos_line_tax_components.order(:calculation_order, :id).each do |component|
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

    def opposite_direction?(source)
      (source.sale? && @line.return?) || (source.return? && @line.sale?)
    end

    def same_merchandise?(source)
      @line.product_variant_id == source.product_variant_id &&
        @line.inventory_unit_id == source.inventory_unit_id
    end
  end
end
