# frozen_string_literal: true

module Inventory
  class RebuildProjection
    class Error < StandardError; end

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(store:, product_variant:, actor:, source_id:, idempotency_key:, correlation_id: nil)
      @store = store
      @product_variant = product_variant
      @actor = actor
      @source_id = source_id
      @idempotency_key = idempotency_key
      @correlation_id = correlation_id || SecureRandom.uuid_v7
    end

    def call
      payload = { store_id: @store.id, product_variant_id: @product_variant.id }
      op = Idempotency::OperationService.begin!(
        source_id: @source_id,
        operation_type: "rebuild_inventory_projection",
        idempotency_key: @idempotency_key,
        payload: payload
      )
      if op.replayed
        return InventoryBalance.find(op.operation.result_id) if op.operation.result_id

        raise Error, "idempotent replay missing result"
      end

      InventoryBalance.transaction do
        balance = InventoryBalance.lock.find_by(store_id: @store.id, product_variant_id: @product_variant.id)
        before = balance&.attributes&.slice("on_hand_quantity", "inventory_value_cents")

        expected_qty = InventoryLedgerEntry.where(
          store_id: @store.id, product_variant_id: @product_variant.id
        ).sum(:quantity_delta)
        expected_value = InventoryValuationEntry.where(
          store_id: @store.id, product_variant_id: @product_variant.id
        ).sum(:value_delta_cents)

        if @product_variant.derived_inventory_tracking == "individual"
          units = InventoryUnit.on_hand.where(store_id: @store.id, product_variant_id: @product_variant.id)
          if units.count != expected_qty || units.sum(:carrying_value_cents) != expected_value
            raise Error, "unit aggregates do not match ledger authority; resolve before rebuild"
          end
        end

        balance ||= InventoryBalance.create!(
          store: @store,
          product_variant: @product_variant,
          on_hand_quantity: 0,
          inventory_value_cents: 0
        )
        balance = InventoryBalance.lock.find(balance.id)
        balance.update!(on_hand_quantity: expected_qty, inventory_value_cents: expected_value)

        Audit::Recorder.record!(
          action: "inventory.projection_rebuilt",
          outcome: "succeeded",
          actor_user: @actor,
          store: @store,
          subject: balance,
          correlation_id: @correlation_id,
          before_values: before,
          after_values: balance.attributes.slice("on_hand_quantity", "inventory_value_cents")
        )

        Outbox::Recorder.record!(
          event_type: "inventory.projection_rebuilt",
          aggregate: balance,
          correlation_id: @correlation_id,
          payload: {
            store_id: @store.id,
            product_variant_id: @product_variant.id,
            on_hand_quantity: expected_qty,
            inventory_value_cents: expected_value
          }
        )

        Idempotency::OperationService.complete!(
          op.operation,
          result_type: "InventoryBalance",
          result_id: balance.id,
          result_payload: { id: balance.id }
        )

        balance
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Idempotency::OperationService.fail!(op.operation, message: e.message) if defined?(op) && op && !op.replayed
      raise Error, e.message
    end
  end
end
