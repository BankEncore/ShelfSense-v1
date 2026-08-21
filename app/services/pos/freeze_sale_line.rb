# frozen_string_literal: true

module Pos
  class FreezeSaleLine
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(transaction:, line:)
      @transaction = transaction
      @line = line
    end

    def call
      variant = @line.product_variant
      tracking = variant.derived_inventory_tracking
      raise Pos::Error, "merchandise is not sellable" unless variant.sellable?
      unless %w[quantity non_inventory individual].include?(tracking)
        raise Pos::Error, "merchandise tracking is not supported"
      end
      raise Pos::Error, "regular price is required" if @line.selling_unit_price_cents.nil?

      unit = freeze_unit_line!(variant, tracking)

      @line.recalc_extended!
      result = Pos::Tax::Calculate.call(
        store: @transaction.store,
        tax_class: @line.tax_class,
        taxable_basis_cents: @line.net_merchandise_amount_cents
      )
      @line.line_tax_cents = result.tax_cents
      @line.line_total_cents = @line.net_merchandise_amount_cents + @line.line_tax_cents
      @line.tax_class_code_snapshot = @line.tax_class.code
      @line.tax_class_name_snapshot ||= @line.tax_class.name
      if @line.default_tax_class_id.present?
        default_class = @line.default_tax_class || TaxClass.find(@line.default_tax_class_id)
        @line.default_tax_class_code_snapshot ||= default_class.code
        @line.default_tax_class_name_snapshot ||= default_class.name
      end
      @line.merchandise_snapshot = merchandise_snapshot_for(variant, unit)
      @line.save!
      @line.pos_line_tax_components.delete_all
      result.determinations.each do |determination|
        @line.pos_line_tax_components.create!(
          store_tax_id: determination.store_tax_id,
          store_tax_code_snapshot: determination.store_tax_code,
          store_tax_name_snapshot: determination.store_tax_name,
          rate_percent: determination.rate_percent,
          applies: determination.applies,
          taxable_basis_cents: determination.taxable_basis_cents,
          tax_cents: determination.tax_cents,
          calculation_order: determination.calculation_order
        )
      end
      @line
    rescue Pos::Tax::UnresolvedApplicability => e
      raise Pos::Error, e.message
    end

    private

    def freeze_unit_line!(variant, tracking)
      if tracking == "individual"
        raise Pos::Error, "inventory unit is required" if @line.inventory_unit_id.blank?
        raise Pos::Error, "quantity must be 1 for individually tracked merchandise" unless @line.quantity == 1

        unit = InventoryUnit.find(@line.inventory_unit_id)
        raise Pos::Error, "unit is not on hand" unless unit.on_hand?
        raise Pos::Error, "unit is not at this store" unless unit.store_id == @transaction.store_id
        raise Pos::Error, "unit does not match the merchandise" unless unit.product_variant_id == variant.id
        unit
      else
        raise Pos::Error, "inventory unit must be blank" if @line.inventory_unit_id.present?

        nil
      end
    rescue ActiveRecord::RecordNotFound
      raise Pos::Error, "unit is not on hand"
    end

    def merchandise_snapshot_for(variant, unit)
      snapshot = {
        "sku" => variant.sku,
        "description" => variant.product.name,
        "tax_class_code" => @line.tax_class.code
      }
      return snapshot if unit.nil?

      condition_code = variant.merchandise_condition&.code
      raise Pos::Error, "condition is required for individually tracked merchandise" if condition_code.blank?

      snapshot.merge(
        "unit_identifier" => unit.unit_identifier,
        "condition_code" => condition_code,
        "condition_name" => variant.merchandise_condition.name
      )
    end
  end
end
