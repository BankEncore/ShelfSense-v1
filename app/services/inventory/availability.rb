# frozen_string_literal: true

module Inventory
  # Shared availability projection for reservation hard-stops.
  # Callers must evaluate under the published lock order (InventoryBalance, then
  # InventoryUnit when Used) before depleting or allocating stock.
  module Availability
    class Error < StandardError; end

    module_function

    def active_reserved_quantity(store, variant)
      CustomerRequestAllocation
        .joins(:customer_request)
        .reserved
        .standard_quantity
        .where(customer_requests: { store_id: store.id, product_variant_id: variant.id })
        .sum(:quantity)
    end

    def available(store, variant, balance: nil)
      on_hand =
        if balance
          balance.on_hand_quantity.to_i
        else
          InventoryBalance.find_by(store_id: store.id, product_variant_id: variant.id)&.on_hand_quantity.to_i
        end
      on_hand - active_reserved_quantity(store, variant)
    end

    def unit_allocated?(inventory_unit, exclude_allocation_id: nil)
      return false if inventory_unit.blank?

      scope = CustomerRequestAllocation.reserved.used_unit.where(inventory_unit_id: inventory_unit.id)
      scope = scope.where.not(id: exclude_allocation_id) if exclude_allocation_id.present?
      scope.exists?
    end

    def unreserved_on_hand_units(store, variant)
      allocated_ids = CustomerRequestAllocation.reserved.used_unit.select(:inventory_unit_id)
      InventoryUnit.on_hand
                   .where(store: store, product_variant: variant)
                   .where.not(id: allocated_ids)
    end

    # Rejects depleting paths that would leave Standard available < 0 or remove an
    # allocated Used unit. Ordinary depleters pass +exclude_allocation_id+ nil.
    # Pickup (Slice 7.6) passes the line's allocation id so capacity =
    # available + that allocation's quantity; Used requires the unit's active
    # allocation to equal that id.
    def assert_depletion_allowed!(store:, variant:, quantity_delta:, inventory_unit: nil,
                                  exclude_allocation_id: nil, balance: nil)
      delta = quantity_delta.to_i
      return if delta >= 0

      excluded = exclude_allocation_id.present? ? CustomerRequestAllocation.find_by(id: exclude_allocation_id) : nil

      if inventory_unit.present?
        if exclude_allocation_id.present?
          unless excluded&.reserved? && excluded.used_unit? && excluded.inventory_unit_id == inventory_unit.id
            raise Error, "inventory unit is not allocated to this customer request"
          end
        elsif unit_allocated?(inventory_unit)
          raise Error, "inventory unit is reserved for a customer request"
        end
      end

      return unless variant.derived_inventory_tracking == "quantity"

      reserved = active_reserved_quantity(store, variant)
      if excluded&.reserved? && excluded.standard_quantity? &&
         excluded.customer_request.store_id == store.id &&
         excluded.customer_request.product_variant_id == variant.id
        reserved -= excluded.quantity
      end

      on_hand =
        if balance
          balance.on_hand_quantity.to_i
        else
          InventoryBalance.find_by(store_id: store.id, product_variant_id: variant.id)&.on_hand_quantity.to_i
        end
      resulting_available = on_hand + delta - reserved
      return if resulting_available >= 0

      raise Error, "insufficient available quantity; reserved stock cannot be depleted"
    end
  end
end
