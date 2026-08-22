# frozen_string_literal: true

module PurchasingHelper
  def stock_orderable_variant?(variant)
    variant.present? &&
      variant.standard? &&
      variant.status == "active" &&
      variant.inventory_mode == "inventory"
  end

  def customer_requestable_variant?(variant, store:)
    return false if variant.blank? || variant.status != "active" || store.blank?
    return true if variant.standard?

    return false unless variant.used?

    Inventory::Availability.unreserved_on_hand_units(store, variant).exists?
  end

  def order_stock_path_for(variant)
    new_admin_order_path(product_variant_id: variant.id)
  end

  def create_customer_request_path_for(variant)
    new_admin_customer_request_path(product_variant_id: variant.id)
  end
end
