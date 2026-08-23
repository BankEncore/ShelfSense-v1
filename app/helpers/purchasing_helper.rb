# frozen_string_literal: true

module PurchasingHelper
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
