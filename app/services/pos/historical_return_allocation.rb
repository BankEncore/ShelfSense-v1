# frozen_string_literal: true

module Pos
  class HistoricalReturnAllocation
    Component = Struct.new(
      :store_tax_id,
      :store_tax_code_snapshot,
      :store_tax_name_snapshot,
      :rate_percent,
      :applies,
      :taxable_basis_cents,
      :tax_cents,
      :calculation_order,
      keyword_init: true
    )

    Result = Struct.new(
      :quantity,
      :extended_selling_amount_cents,
      :manual_discount_cents,
      :net_merchandise_amount_cents,
      :line_tax_cents,
      :line_total_cents,
      :inventory_value_cents,
      :components,
      keyword_init: true
    )

    def self.call(original_line:, requested_quantity:, excluding_line_id: nil)
      new(
        original_line: original_line,
        requested_quantity: requested_quantity,
        excluding_line_id: excluding_line_id
      ).call
    end

    def initialize(original_line:, requested_quantity:, excluding_line_id: nil)
      @original = original_line
      @requested_quantity = requested_quantity.to_i
      @excluding_line_id = excluding_line_id
    end

    def call
      remaining_quantity = Pos::Returnability.remaining_quantity(@original, excluding_line_id: @excluding_line_id)
      raise Pos::Error, "return quantity must be positive" unless @requested_quantity.positive?
      raise Pos::Error, "return quantity exceeds remaining quantity" if @requested_quantity > remaining_quantity

      completed = Pos::Returnability.completed_linked_returns(@original)
      completed = completed.where.not(id: @excluding_line_id) if @excluding_line_id
      completed_ids = completed.pluck(:id)
      completed_discount = completed.sum(:manual_discount_cents)
      completed_components = completed_component_totals(completed_ids)
      completed_inventory = completed_inventory_value(completed_ids)

      discount = allocate_cents(
        original_cents: @original.manual_discount_cents,
        completed_cents: completed_discount,
        remaining_quantity: remaining_quantity
      )
      extended = @original.selling_unit_price_cents * @requested_quantity
      net = extended - discount
      components = @original.pos_line_tax_components.order(:calculation_order, :store_tax_code_snapshot, :id).map do |component|
        consumed = completed_components.fetch(component_key(component), { basis: 0, tax: 0 })
        allocated_basis = allocate_cents(
          original_cents: component.taxable_basis_cents,
          completed_cents: consumed[:basis],
          remaining_quantity: remaining_quantity
        )
        allocated_tax = allocate_cents(
          original_cents: component.tax_cents,
          completed_cents: consumed[:tax],
          remaining_quantity: remaining_quantity
        )
        Component.new(
          store_tax_id: component.store_tax_id,
          store_tax_code_snapshot: component.store_tax_code_snapshot,
          store_tax_name_snapshot: component.store_tax_name_snapshot,
          rate_percent: component.rate_percent,
          applies: component.applies,
          taxable_basis_cents: allocated_basis,
          tax_cents: allocated_tax,
          calculation_order: component.calculation_order
        )
      end
      tax = components.sum(&:tax_cents)
      inventory = allocate_cents(
        original_cents: original_inventory_value,
        completed_cents: completed_inventory,
        remaining_quantity: remaining_quantity
      )

      Result.new(
        quantity: @requested_quantity,
        extended_selling_amount_cents: extended,
        manual_discount_cents: discount,
        net_merchandise_amount_cents: net,
        line_tax_cents: tax,
        line_total_cents: net + tax,
        inventory_value_cents: inventory,
        components: components
      )
    end

    private

    def allocate_cents(original_cents:, completed_cents:, remaining_quantity:)
      remaining_cents = original_cents - completed_cents
      return remaining_cents if @requested_quantity == remaining_quantity
      return 0 if @original.quantity <= 0 || original_cents.zero?

      proportional = Inventory::Costing.round_half_up(
        BigDecimal(original_cents.to_s) * @requested_quantity / @original.quantity
      )
      [ proportional, remaining_cents ].min
    end

    def original_inventory_value
      tracking = @original.product_variant.derived_inventory_tracking
      return 0 if tracking == "non_inventory"
      unless %w[quantity individual].include?(tracking)
        raise Pos::Error, "merchandise tracking is not supported"
      end

      valuation = InventoryValuationEntry.find_by(
        source_type: "PosTransactionLine",
        source_id: @original.id,
        entry_type: "depletion"
      )
      raise Pos::Error, "original sale inventory valuation is missing" if valuation.nil?
      raise Pos::Error, "original sale inventory valuation is malformed" if valuation.value_delta_cents.positive?

      -valuation.value_delta_cents
    end

    def completed_inventory_value(completed_ids)
      return 0 if completed_ids.empty?

      InventoryValuationEntry.where(
        source_type: "PosTransactionLine",
        source_id: completed_ids,
        entry_type: "acquisition"
      ).sum(:value_delta_cents)
    end

    def completed_component_totals(completed_ids)
      totals = Hash.new { |hash, key| hash[key] = { basis: 0, tax: 0 } }
      return totals if completed_ids.empty?

      PosLineTaxComponent.where(pos_transaction_line_id: completed_ids).find_each do |component|
        key = component_key(component)
        totals[key][:basis] += component.taxable_basis_cents
        totals[key][:tax] += component.tax_cents
      end
      totals
    end

    def component_key(component)
      [ component.store_tax_id, component.calculation_order ]
    end
  end
end
