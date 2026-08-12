# frozen_string_literal: true

module Inventory
  class Reconcile
    Drift = Struct.new(
      :store_id, :product_variant_id, :kind, :expected, :actual, :message,
      keyword_init: true
    )

    def self.call(store: nil)
      new(store: store).call
    end

    def initialize(store: nil)
      @store = store
    end

    def call
      drifts = []
      scope = InventoryBalance.all
      scope = scope.where(store_id: @store.id) if @store

      scope.find_each do |balance|
        drifts.concat(check_balance(balance))
      end

      ledgers = InventoryLedgerEntry.all
      ledgers = ledgers.where(store_id: @store.id) if @store
      ledgers.select(:store_id, :product_variant_id).distinct.find_each do |row|
        next if InventoryBalance.exists?(store_id: row.store_id, product_variant_id: row.product_variant_id)

        drifts << Drift.new(
          store_id: row.store_id,
          product_variant_id: row.product_variant_id,
          kind: "missing_balance",
          expected: nil,
          actual: nil,
          message: "ledger history without balance row"
        )
      end

      drifts
    end

    private

    def check_balance(balance)
      drifts = []
      expected_qty = InventoryLedgerEntry.where(
        store_id: balance.store_id, product_variant_id: balance.product_variant_id
      ).sum(:quantity_delta)
      expected_value = InventoryValuationEntry.where(
        store_id: balance.store_id, product_variant_id: balance.product_variant_id
      ).sum(:value_delta_cents)

      if expected_qty != balance.on_hand_quantity
        drifts << Drift.new(
          store_id: balance.store_id,
          product_variant_id: balance.product_variant_id,
          kind: "quantity",
          expected: expected_qty,
          actual: balance.on_hand_quantity,
          message: "on-hand quantity drift"
        )
      end
      if expected_value != balance.inventory_value_cents
        drifts << Drift.new(
          store_id: balance.store_id,
          product_variant_id: balance.product_variant_id,
          kind: "value",
          expected: expected_value,
          actual: balance.inventory_value_cents,
          message: "inventory value drift"
        )
      end
      if balance.on_hand_quantity.zero? && balance.inventory_value_cents != 0
        drifts << Drift.new(
          store_id: balance.store_id,
          product_variant_id: balance.product_variant_id,
          kind: "residual_value",
          expected: 0,
          actual: balance.inventory_value_cents,
          message: "zero quantity with residual value"
        )
      end

      variant = balance.product_variant
      if variant.derived_inventory_tracking == "individual"
        units = InventoryUnit.on_hand.where(store_id: balance.store_id, product_variant_id: balance.product_variant_id)
        if units.count != balance.on_hand_quantity
          drifts << Drift.new(
            store_id: balance.store_id,
            product_variant_id: balance.product_variant_id,
            kind: "unit_count",
            expected: units.count,
            actual: balance.on_hand_quantity,
            message: "on-hand unit count mismatch"
          )
        end
        unit_value = units.sum(:carrying_value_cents)
        if unit_value != balance.inventory_value_cents
          drifts << Drift.new(
            store_id: balance.store_id,
            product_variant_id: balance.product_variant_id,
            kind: "unit_value",
            expected: unit_value,
            actual: balance.inventory_value_cents,
            message: "on-hand unit value mismatch"
          )
        end
      end

      drifts
    end
  end
end
