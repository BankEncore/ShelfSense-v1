# frozen_string_literal: true

module Inventory
  module Balances
    module_function

    def lock_or_create!(store:, product_variant:)
      balance = InventoryBalance.lock.find_by(store_id: store.id, product_variant_id: product_variant.id)
      return balance if balance

      begin
        InventoryBalance.transaction(requires_new: true) do
          InventoryBalance.create!(
            store: store,
            product_variant: product_variant,
            on_hand_quantity: 0,
            inventory_value_cents: 0
          )
        end
      rescue ActiveRecord::RecordNotUnique
        InventoryBalance.lock.find_by!(store_id: store.id, product_variant_id: product_variant.id)
      else
        InventoryBalance.lock.find_by!(store_id: store.id, product_variant_id: product_variant.id)
      end
    end
  end
end
