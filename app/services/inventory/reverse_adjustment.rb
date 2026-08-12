# frozen_string_literal: true

module Inventory
  class ReverseAdjustment
    class Error < StandardError; end

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      adjustment:,
      actor:,
      source_id:,
      idempotency_key:,
      notes:,
      allow_backdate: false,
      occurred_at: nil,
      correlation_id: nil
    )
      @original = adjustment
      @actor = actor
      @source_id = source_id
      @idempotency_key = idempotency_key
      @notes = notes
      @allow_backdate = allow_backdate
      @occurred_at = occurred_at
      @correlation_id = correlation_id || SecureRandom.uuid_v7
    end

    def call
      payload = {
        adjustment_id: @original.id,
        notes: @notes,
        occurred_at: @occurred_at&.iso8601(6)
      }
      op = Idempotency::OperationService.begin!(
        source_id: @source_id,
        operation_type: "reverse_inventory_adjustment",
        idempotency_key: @idempotency_key,
        payload: payload
      )
      if op.replayed
        return InventoryAdjustment.find(op.operation.result_id) if op.operation.result_id

        raise Error, "idempotent replay missing result"
      end

      InventoryAdjustment.transaction do
        original = InventoryAdjustment.lock.find(@original.id)
        raise Error, "adjustment already reversed" if original.reversed?
        raise Error, "cannot reverse a reversal" if original.reversal?
        raise Error, "notes are required" if @notes.blank?

        reason = AdjustmentReason.find_by!(code: "reversal")
        ledger = InventoryLedgerEntry.find_by!(source_type: "InventoryAdjustment", source_id: original.id, effect_sequence: 0)
        valuation = InventoryValuationEntry.find_by!(source_type: "InventoryAdjustment", source_id: original.id, effect_sequence: 0)

        validate_unit_eligibility!(original)

        balance = InventoryBalance.lock.find_by!(
          store_id: original.store_id,
          product_variant_id: original.product_variant_id
        )

        qty_delta = -original.quantity_delta
        value_delta = -valuation.value_delta_cents
        resulting_qty = balance.on_hand_quantity + qty_delta
        resulting_value = balance.inventory_value_cents + value_delta
        if resulting_qty.negative? || resulting_value.negative?
          raise Error, "reversal would reduce on-hand or value below zero"
        end

        occurred_at = @occurred_at.presence || Time.current
        business_date = BusinessDate.for_store(original.store, at: occurred_at)

        unit = original.inventory_unit
        if unit
          unit = InventoryUnit.lock.find(unit.id)
          if original.quantity_delta.positive?
            raise Error, "unit must still be on hand to reverse acquisition" unless unit.on_hand?
            unit.update!(lifecycle_state: "removed", removed_at: Time.current)
          else
            raise Error, "unit must still be removed to reverse removal" unless unit.removed?
            unit.update!(lifecycle_state: "on_hand", removed_at: nil)
          end
        end

        reversal = InventoryAdjustment.create!(
          store: original.store,
          product_variant: original.product_variant,
          inventory_unit: unit,
          adjustment_reason: reason,
          quantity_delta: qty_delta,
          acquisition_unit_cost_cents: original.acquisition_unit_cost_cents,
          notes: @notes,
          created_by: @actor,
          business_date: business_date,
          occurred_at: occurred_at,
          posted_at: Time.current,
          reversal_of: original
        )

        new_ledger = InventoryLedgerEntry.create!(
          store: original.store,
          product_variant: original.product_variant,
          inventory_unit: unit,
          quantity_delta: qty_delta,
          entry_type: "reversal",
          source_type: "InventoryAdjustment",
          source_id: reversal.id,
          effect_sequence: 0,
          business_date: business_date,
          occurred_at: occurred_at,
          actor_type: "User",
          actor_id: @actor.id,
          reversal_of: ledger
        )

        InventoryValuationEntry.create!(
          store: original.store,
          product_variant: original.product_variant,
          inventory_unit: unit,
          quantity_delta: qty_delta,
          value_delta_cents: value_delta,
          acquisition_unit_cost_cents: original.acquisition_unit_cost_cents,
          valuation_method: valuation.valuation_method,
          entry_type: "reversal",
          source_type: "InventoryAdjustment",
          source_id: reversal.id,
          effect_sequence: 0,
          calculation_metadata: { reversal_of_valuation_id: valuation.id },
          business_date: business_date,
          occurred_at: occurred_at,
          reversal_of: valuation
        )

        balance.update!(on_hand_quantity: resulting_qty, inventory_value_cents: resulting_value)
        original.update!(reversed_at: Time.current)

        Audit::Recorder.record!(
          action: "inventory.adjustment_reversed",
          outcome: "succeeded",
          actor_user: @actor,
          store: original.store,
          subject: reversal,
          correlation_id: @correlation_id,
          after_values: {
            reversal_of_id: original.id,
            quantity_delta: qty_delta,
            value_delta_cents: value_delta
          },
          metadata: { ledger_id: new_ledger.id }
        )

        Outbox::Recorder.record!(
          event_type: "inventory.adjustment_reversed",
          aggregate: reversal,
          correlation_id: @correlation_id,
          occurred_at: reversal.posted_at,
          payload: { reversal_of_id: original.id, quantity_delta: qty_delta, value_delta_cents: value_delta }
        )

        Idempotency::OperationService.complete!(
          op.operation,
          result_type: "InventoryAdjustment",
          result_id: reversal.id,
          result_payload: { id: reversal.id }
        )

        reversal
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Idempotency::OperationService.fail!(op.operation, message: e.message) if defined?(op) && op && !op.replayed
      raise Error, e.message
    end

    private

    def validate_unit_eligibility!(original)
      return if original.inventory_unit_id.blank?

      unit = InventoryUnit.find(original.inventory_unit_id)
      if original.quantity_delta.positive?
        raise Error, "unit must still be on hand to reverse acquisition" unless unit.on_hand?
      else
        raise Error, "unit must still be removed to reverse removal" unless unit.removed?
      end
    end
  end
end
