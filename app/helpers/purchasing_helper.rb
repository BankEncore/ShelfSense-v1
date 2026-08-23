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

  def purchasing_hub_nav_visible?
    return false unless current_user

    Purchasing::HubAccess.nav_visible?(user: current_user, accessible_stores: accessible_stores)
  end

  def purchasing_link_to(label, url, **options)
    return if url.blank?

    link_to(label, url, **options)
  end

  def admin_order_link(order, label: nil)
    return unless order
    return unless purchasing_can_view_order?(order)

    label ||= order.admin_label
    link_to(label, admin_order_path(order))
  end

  def admin_purchase_order_link(purchase_order, label: nil)
    return unless purchase_order
    return unless purchasing_can_view_purchase_order?(purchase_order)

    label ||= purchase_order.admin_label
    link_to(label, admin_purchase_order_path(purchase_order))
  end

  def admin_purchase_receipt_link(receipt, label: nil)
    return unless receipt
    return unless purchasing_can_view_purchase_receipt?(receipt)

    label ||= receipt.admin_label
    link_to(label, admin_purchase_receipt_path(receipt))
  end

  def admin_customer_request_link(request, label: nil)
    return unless request
    return unless purchasing_can_view_customer_request?(request)

    label ||= request.admin_label
    link_to(label, admin_customer_request_path(request))
  end

  def ops_draft_purchase_order_link(purchase_order, label: nil)
    return unless purchase_order
    return unless purchasing_can_manage_draft_po?(purchase_order)

    label ||= "Open draft workspace"
    link_to(label, ops_purchase_order_path(purchase_order))
  end

  def ops_receiving_link(receipt, label: nil)
    return unless receipt
    return unless purchasing_can_access_receiving?(receipt)

    label ||= "Ops receiving view"
    link_to(label, ops_receiving_path(receipt))
  end

  private

  def purchasing_can_view_order?(order)
    Authorization::PermissionEvaluator.allowed?(
      user: current_user,
      permission_key: "orders.view",
      store: order.store
    )
  end

  def purchasing_can_view_purchase_order?(purchase_order)
    Authorization::PermissionEvaluator.allowed?(
      user: current_user,
      permission_key: "orders.view",
      store: purchase_order.store
    )
  end

  def purchasing_can_view_purchase_receipt?(receipt)
    Authorization::PermissionEvaluator.allowed?(
      user: current_user,
      permission_key: "purchase_receipts.view",
      store: receipt.store
    )
  end

  def purchasing_can_view_customer_request?(request)
    Authorization::PermissionEvaluator.allowed?(
      user: current_user,
      permission_key: "customers.view",
      store: request.store
    )
  end

  def purchasing_can_manage_draft_po?(purchase_order)
    return false unless purchase_order.draft?

    Authorization::PermissionEvaluator.allowed?(
      user: current_user,
      permission_key: "orders.manage",
      store: purchase_order.store
    ) && current_store&.id == purchase_order.store_id
  end

  def purchasing_can_access_receiving?(receipt)
    Authorization::PermissionEvaluator.allowed?(
      user: current_user,
      permission_key: "purchase_receipts.view",
      store: receipt.store
    ) && current_store&.id == receipt.store_id
  end
end
