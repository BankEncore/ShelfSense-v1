# frozen_string_literal: true

module Inventory
  class ReturnValuation
    class Error < StandardError; end

    Result = Struct.new(:incoming_value_cents, :basis, keyword_init: true)

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(store:, variant:, quantity:, inventory_unit: nil, balance: nil)
      @store = store
      @variant = variant
      @quantity = quantity.to_i
      @inventory_unit = inventory_unit
      @balance = balance
    end

    def call
      raise Error, "quantity must be positive" unless @quantity.positive?

      tracking = @variant.derived_inventory_tracking
      case tracking
      when "individual"
        value_for_unit
      when "quantity"
        value_for_quantity
      else
        raise Error, "variant is not inventory-tracked"
      end
    end

    private

    def value_for_unit
      raise Error, "inventory unit is required" if @inventory_unit.nil?

      Result.new(
        incoming_value_cents: @inventory_unit.carrying_value_cents,
        basis: "unit_carrying_value"
      )
    end

    def value_for_quantity
      on_hand = current_on_hand
      if on_hand.positive?
        incoming = Costing.round_half_up(
          BigDecimal(current_value.to_s) * @quantity / on_hand
        )
        return Result.new(incoming_value_cents: incoming, basis: "current_moving_average")
      end

      latest = latest_valuation_entry
      metadata = latest&.calculation_metadata
      prior_quantity = metadata.is_a?(Hash) ? metadata["prior_quantity"].to_i : 0
      prior_value = metadata.is_a?(Hash) ? metadata["prior_value_cents"].to_i : 0
      unless prior_quantity.positive?
        raise Error, "no defensible inventory valuation basis"
      end

      incoming = Costing.round_half_up(
        BigDecimal(prior_value.to_s) * @quantity / prior_quantity
      )
      Result.new(incoming_value_cents: incoming, basis: "latest_prior_moving_average")
    end

    def current_on_hand
      resolved_balance&.on_hand_quantity.to_i
    end

    def current_value
      resolved_balance&.inventory_value_cents.to_i
    end

    def resolved_balance
      return @balance if @balance

      InventoryBalance.find_by(store_id: @store.id, product_variant_id: @variant.id)
    end

    def latest_valuation_entry
      InventoryValuationEntry.where(store_id: @store.id, product_variant_id: @variant.id)
                             .order(occurred_at: :desc, id: :desc)
                             .first
    end
  end
end
