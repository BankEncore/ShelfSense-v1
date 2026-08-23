# frozen_string_literal: true

# Permission-aware non-purchasing admin cross-links (UDS-4.2).
# Returns nil when the destination is unauthorized or the record is blank.
# Store-scoped destinations evaluate permission against the destination store,
# not merely current_store / effective_permissions.
module AdminCrossLinksHelper
  def admin_product_link(product, label: nil)
    return unless product
    return unless effective_permissions.include?("products.view")

    link_to(label || product.name, admin_product_path(product))
  end

  def admin_product_variant_link(variant, label: nil)
    return unless variant
    return unless effective_permissions.include?("product_variants.view")

    link_to(label || (variant.name.presence || variant.sku), admin_product_variant_path(variant))
  end

  def admin_merchandise_category_link(category, label: nil)
    return unless category
    return unless effective_permissions.include?("merchandise_categories.view")

    link_to(label || category.admin_label, admin_merchandise_category_path(category))
  end

  def admin_merchandise_class_link(merchandise_class, label: nil)
    return unless merchandise_class
    return unless effective_permissions.include?("merchandise_classes.view")

    link_to(label || merchandise_class.admin_label, admin_merchandise_class_path(merchandise_class))
  end

  def admin_department_link(department, label: nil)
    return unless department
    return unless effective_permissions.include?("departments.view")

    link_to(label || department.admin_label, admin_department_path(department))
  end

  def admin_tax_class_link(tax_class, label: nil)
    return unless tax_class
    return unless effective_permissions.include?("tax_classes.view")

    link_to(label || tax_class.admin_label, admin_tax_class_path(tax_class))
  end

  def admin_inventory_balance_link(balance, label: nil)
    return unless balance
    return unless permission_allowed_at?("inventory.view", store: balance.store)

    link_to(label || balance.on_hand_quantity.to_s, admin_inventory_balance_path(balance))
  end

  def admin_inventory_adjust_link(store:, product_variant:, label: "Adjust inventory")
    return if store.blank? || product_variant.blank?
    return unless permission_allowed_at?("inventory.adjust", store: store)

    link_to(
      label,
      new_admin_inventory_adjustment_path(store_id: store.id, product_variant_id: product_variant.id)
    )
  end

  def admin_customer_link(customer, label: nil)
    return unless customer
    return unless effective_permissions.include?("customers.view")

    link_to(label || customer.admin_label, admin_customer_path(customer))
  end

  def admin_customer_request_cross_link(request, label: nil)
    return unless request
    return unless permission_allowed_at?("customers.view", store: request.store)

    link_to(label || request.admin_label, admin_customer_request_path(request))
  end

  def pos_transaction_cross_link(transaction, label: nil)
    return unless transaction
    return unless permission_allowed_at?("pos.transact", store: transaction.store)

    text = label.presence || transaction.try(:receipt_number).presence || "Transaction #{transaction.id}"
    link_to(text, pos_transaction_path(transaction))
  end

  private

  def permission_allowed_at?(permission_key, store:)
    return false unless current_user && store

    @admin_cross_link_permissions ||= {}
    key = [permission_key, store.id]

    @admin_cross_link_permissions.fetch(key) do
      @admin_cross_link_permissions[key] =
        Authorization::PermissionEvaluator.allowed?(
          user: current_user,
          permission_key: permission_key,
          store: store
        )
    end
  end
end
