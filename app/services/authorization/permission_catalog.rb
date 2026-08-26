# frozen_string_literal: true

module Authorization
  module PermissionCatalog
    module_function

    PHASE1_PERMISSIONS = [
      { key: "system_settings.view", group_key: "system_settings", name: "View system settings", scope_type: "global" },
      { key: "system_settings.manage", group_key: "system_settings", name: "Manage system settings", scope_type: "global" },
      { key: "stores.view", group_key: "stores", name: "View stores", scope_type: "either" },
      { key: "stores.create", group_key: "stores", name: "Create stores", scope_type: "global" },
      { key: "stores.manage", group_key: "stores", name: "Manage stores", scope_type: "either" },
      { key: "stores.deactivate", group_key: "stores", name: "Deactivate stores", scope_type: "global" },
      { key: "users.view", group_key: "users", name: "View users", scope_type: "global" },
      { key: "users.create", group_key: "users", name: "Create users", scope_type: "global" },
      { key: "users.manage", group_key: "users", name: "Manage users", scope_type: "global" },
      { key: "users.deactivate", group_key: "users", name: "Deactivate users", scope_type: "global" },
      { key: "users.assign_roles", group_key: "users", name: "Assign roles", scope_type: "global" },
      { key: "users.revoke_sessions", group_key: "users", name: "Revoke sessions", scope_type: "global" },
      { key: "roles.view", group_key: "roles", name: "View roles", scope_type: "global" },
      { key: "roles.create", group_key: "roles", name: "Create roles", scope_type: "global" },
      { key: "roles.manage", group_key: "roles", name: "Manage roles", scope_type: "global" },
      { key: "roles.deactivate", group_key: "roles", name: "Deactivate roles", scope_type: "global" },
      { key: "registers.view", group_key: "registers", name: "View registers", scope_type: "either" },
      { key: "registers.create", group_key: "registers", name: "Create registers", scope_type: "either" },
      { key: "registers.manage", group_key: "registers", name: "Manage registers", scope_type: "either" },
      { key: "registers.deactivate", group_key: "registers", name: "Deactivate registers", scope_type: "either" },
      { key: "audit_events.view", group_key: "audit_events", name: "View audit events", scope_type: "either" }
    ].freeze

    # View/lookup keys use scope_type "either" so store-scoped roles (associate,
    # store_manager) can read organization-wide catalog data in an active store.
    # Create/update/lifecycle keys remain "global" and require a global assignment.
    PHASE2_PERMISSIONS = [
      { key: "gl_accounts.view", group_key: "gl_accounts", name: "View GL accounts", scope_type: "either" },
      { key: "gl_accounts.create", group_key: "gl_accounts", name: "Create GL accounts", scope_type: "global" },
      { key: "gl_accounts.update", group_key: "gl_accounts", name: "Update GL accounts", scope_type: "global" },
      { key: "gl_accounts.deactivate", group_key: "gl_accounts", name: "Deactivate GL accounts", scope_type: "global" },
      { key: "tax_classes.view", group_key: "tax_classes", name: "View tax classes", scope_type: "either" },
      { key: "tax_classes.create", group_key: "tax_classes", name: "Create tax classes", scope_type: "global" },
      { key: "tax_classes.update", group_key: "tax_classes", name: "Update tax classes", scope_type: "global" },
      { key: "tax_classes.deactivate", group_key: "tax_classes", name: "Deactivate tax classes", scope_type: "global" },
      { key: "departments.view", group_key: "departments", name: "View departments", scope_type: "either" },
      { key: "departments.create", group_key: "departments", name: "Create departments", scope_type: "global" },
      { key: "departments.update", group_key: "departments", name: "Update departments", scope_type: "global" },
      { key: "departments.deactivate", group_key: "departments", name: "Deactivate departments", scope_type: "global" },
      { key: "merchandise_classes.view", group_key: "merchandise_classes", name: "View merchandise classes", scope_type: "either" },
      { key: "merchandise_classes.create", group_key: "merchandise_classes", name: "Create merchandise classes", scope_type: "global" },
      { key: "merchandise_classes.update", group_key: "merchandise_classes", name: "Update merchandise classes", scope_type: "global" },
      { key: "merchandise_classes.deactivate", group_key: "merchandise_classes", name: "Deactivate merchandise classes", scope_type: "global" },
      { key: "merchandise_categories.view", group_key: "merchandise_categories", name: "View merchandise categories", scope_type: "either" },
      { key: "merchandise_categories.create", group_key: "merchandise_categories", name: "Create merchandise categories", scope_type: "global" },
      { key: "merchandise_categories.update", group_key: "merchandise_categories", name: "Update merchandise categories", scope_type: "global" },
      { key: "merchandise_categories.deactivate", group_key: "merchandise_categories", name: "Deactivate merchandise categories", scope_type: "global" },
      { key: "merchandise_conditions.view", group_key: "merchandise_conditions", name: "View merchandise conditions", scope_type: "either" },
      { key: "merchandise_conditions.create", group_key: "merchandise_conditions", name: "Create merchandise conditions", scope_type: "global" },
      { key: "merchandise_conditions.update", group_key: "merchandise_conditions", name: "Update merchandise conditions", scope_type: "global" },
      { key: "merchandise_conditions.deactivate", group_key: "merchandise_conditions", name: "Deactivate merchandise conditions", scope_type: "global" },
      { key: "products.view", group_key: "products", name: "View products", scope_type: "either" },
      { key: "products.create", group_key: "products", name: "Create products", scope_type: "global" },
      { key: "products.update", group_key: "products", name: "Update products", scope_type: "global" },
      { key: "products.discontinue", group_key: "products", name: "Discontinue or reactivate products", scope_type: "global" },
      { key: "product_variants.view", group_key: "product_variants", name: "View product variants", scope_type: "either" },
      { key: "product_variants.create", group_key: "product_variants", name: "Create product variants", scope_type: "global" },
      { key: "product_variants.update", group_key: "product_variants", name: "Update product variants", scope_type: "global" },
      { key: "product_variants.discontinue", group_key: "product_variants", name: "Discontinue product variants", scope_type: "global" },
      { key: "merchandise.lookup", group_key: "merchandise", name: "Look up merchandise by identifier", scope_type: "either" },
      { key: "merchandise.import", group_key: "merchandise", name: "Import merchandise", scope_type: "global" }
    ].freeze

    PHASE3_PERMISSIONS = [
      { key: "inventory.view", group_key: "inventory", name: "View inventory", scope_type: "either" },
      { key: "inventory.adjust", group_key: "inventory", name: "Post inventory adjustments", scope_type: "either" },
      { key: "inventory.reverse_adjustment", group_key: "inventory", name: "Reverse inventory adjustments", scope_type: "either" },
      { key: "inventory.manage_adjustment_reasons", group_key: "inventory", name: "Manage adjustment reasons", scope_type: "global" },
      { key: "inventory.reconcile", group_key: "inventory", name: "Reconcile and rebuild inventory projections", scope_type: "global" },
      { key: "inventory.backdate", group_key: "inventory", name: "Backdate inventory events", scope_type: "either" }
    ].freeze

    PHASE4_PERMISSIONS = [
      { key: "store_taxes.view", group_key: "store_taxes", name: "View store taxes", scope_type: "either" },
      { key: "store_taxes.create", group_key: "store_taxes", name: "Create store taxes", scope_type: "either" },
      { key: "store_taxes.update", group_key: "store_taxes", name: "Update store taxes", scope_type: "either" },
      { key: "store_taxes.deactivate", group_key: "store_taxes", name: "Deactivate store taxes", scope_type: "either" },
      { key: "pos.transact", group_key: "pos", name: "Operate POS transactions", scope_type: "either" },
      { key: "pos.sessions.view", group_key: "pos", name: "View other open POS sessions", scope_type: "either" },
      { key: "pos.manage_tender_types", group_key: "pos", name: "Manage tender types", scope_type: "global" },
      { key: "pos.price_override.perform", group_key: "pos", name: "Perform price override", scope_type: "either" },
      { key: "pos.price_override.approve", group_key: "pos", name: "Approve price override", scope_type: "either" },
      { key: "pos.line_discount.perform", group_key: "pos", name: "Perform line discount", scope_type: "either" },
      { key: "pos.line_discount.approve", group_key: "pos", name: "Approve line discount", scope_type: "either" },
      { key: "pos.tax_class_override.perform", group_key: "pos", name: "Perform Tax Class override", scope_type: "either" },
      { key: "pos.tax_class_override.approve", group_key: "pos", name: "Approve Tax Class override", scope_type: "either" },
      { key: "pos.unlinked_return.perform", group_key: "pos", name: "Perform unlinked return", scope_type: "either" },
      { key: "pos.unlinked_return.approve", group_key: "pos", name: "Approve unlinked return", scope_type: "either" },
      { key: "pos.post_void.perform", group_key: "pos", name: "Perform post-void", scope_type: "either" },
      { key: "pos.post_void.approve", group_key: "pos", name: "Approve post-void", scope_type: "either" }
    ].freeze

    # Supplier configuration may be maintained with an either-scoped assignment so
    # store managers can set store source preferences for their authorized store.
    # Customer request locate/manage are either-scoped so associates can operate
    # at their assigned store.
    PHASE7_PERMISSIONS = [
      { key: "suppliers.view", group_key: "suppliers", name: "View suppliers and sources", scope_type: "either" },
      { key: "suppliers.manage", group_key: "suppliers", name: "Manage suppliers and sources", scope_type: "either" },
      { key: "customers.view", group_key: "customers", name: "View customers and requests", scope_type: "either" },
      { key: "customers.manage", group_key: "customers", name: "Manage customer identity", scope_type: "either" },
      { key: "customer_requests.manage", group_key: "customer_requests", name: "Create, edit, and cancel customer requests", scope_type: "either" },
      { key: "customer_requests.locate", group_key: "customer_requests", name: "Locate and resolve pending customer requests", scope_type: "either" },
      { key: "customer_requests.pickup", group_key: "customer_requests", name: "Select and fulfill an available customer allocation through POS", scope_type: "either" },
      { key: "orders.view", group_key: "orders", name: "View orders and purchase orders", scope_type: "either" },
      { key: "orders.manage", group_key: "orders", name: "Create and edit draft orders and purchase-order lines", scope_type: "either" },
      { key: "purchase_orders.send", group_key: "purchase_orders", name: "Generate and send purchase orders", scope_type: "either" },
      { key: "purchase_orders.cancel", group_key: "purchase_orders", name: "Cancel purchase-order quantity and re-source", scope_type: "either" },
      { key: "purchase_receipts.view", group_key: "purchase_receipts", name: "View purchase receipts", scope_type: "either" },
      { key: "purchase_receipts.manage", group_key: "purchase_receipts", name: "Create and edit draft purchase receipts", scope_type: "either" },
      { key: "purchase_receipts.post", group_key: "purchase_receipts", name: "Post purchase receipts and inventory effects", scope_type: "either" },
      { key: "purchase_receipts.backdate", group_key: "purchase_receipts", name: "Supply a permitted past received time", scope_type: "either" },
      { key: "purchase_receipts.correct", group_key: "purchase_receipts", name: "Reverse eligible receipt lines and post cost-only corrections", scope_type: "either" },
      { key: "purchase_receipts.compensate", group_key: "purchase_receipts", name: "Authorize compensating adjustments when exact receipt reversal is unsafe", scope_type: "either" }
    ].freeze

    PHASE10_PERMISSIONS = [
      { key: "stored_value.view_activity", group_key: "stored_value", name: "View stored-value activity", scope_type: "either" },
      { key: "stored_value.adjust", group_key: "stored_value", name: "Adjust stored-value accounts", scope_type: "either" },
      { key: "stored_value.transfer", group_key: "stored_value", name: "Transfer stored-value accounts", scope_type: "either" },
      { key: "stored_value.manage_adjustment_reasons", group_key: "stored_value", name: "Manage stored-value adjustment reasons", scope_type: "global" },
      { key: "gift_cards.manage_programs", group_key: "gift_cards", name: "Manage gift-card programs", scope_type: "global" },
      { key: "gift_cards.view", group_key: "gift_cards", name: "View gift cards", scope_type: "either" },
      { key: "gift_cards.suspend", group_key: "gift_cards", name: "Suspend or reinstate gift cards", scope_type: "either" },
      { key: "gift_cards.replace", group_key: "gift_cards", name: "Replace gift cards", scope_type: "either" },
      { key: "gift_cards.associate_customer", group_key: "gift_cards", name: "Associate gift cards with customers", scope_type: "either" },
      { key: "gift_cards.cash_out", group_key: "gift_cards", name: "Cash out gift cards", scope_type: "either" },
      { key: "gift_cards.recover_print", group_key: "gift_cards", name: "Recover gift-card print", scope_type: "either" }
    ].freeze

    PHASE9_PERMISSIONS = [
      { key: "product_forms.view", group_key: "product_forms", name: "View product forms", scope_type: "either" },
      { key: "product_forms.update", group_key: "product_forms", name: "Update product forms", scope_type: "global" },
      { key: "product_forms.deactivate", group_key: "product_forms", name: "Deactivate product forms", scope_type: "global" },
      { key: "subject_schemes.view", group_key: "subject_schemes", name: "View subject schemes", scope_type: "either" },
      { key: "subject_schemes.update", group_key: "subject_schemes", name: "Update subject schemes", scope_type: "global" },
      { key: "subject_headings.view", group_key: "subject_headings", name: "View subject headings", scope_type: "either" },
      { key: "subject_headings.create", group_key: "subject_headings", name: "Create subject headings", scope_type: "global" },
      { key: "subject_headings.update", group_key: "subject_headings", name: "Update subject headings", scope_type: "global" },
      { key: "subject_headings.deactivate", group_key: "subject_headings", name: "Deactivate subject headings", scope_type: "global" }
    ].freeze

    PERMISSIONS = (
      PHASE1_PERMISSIONS + PHASE2_PERMISSIONS + PHASE3_PERMISSIONS + PHASE4_PERMISSIONS + PHASE7_PERMISSIONS + PHASE9_PERMISSIONS + PHASE10_PERMISSIONS
    ).freeze

    STORE_MANAGER_PHASE2_VIEWS = %w[
      gl_accounts.view
      tax_classes.view
      departments.view
      merchandise_classes.view
      merchandise_categories.view
      merchandise_conditions.view
      products.view
      product_variants.view
      merchandise.lookup
    ].freeze

    STORE_MANAGER_PHASE9_VIEWS = %w[
      product_forms.view
      subject_schemes.view
      subject_headings.view
    ].freeze

    STORE_MANAGER_PHASE10 = %w[
      stored_value.view_activity
      stored_value.adjust
      stored_value.transfer
      gift_cards.view
      gift_cards.suspend
      gift_cards.replace
      gift_cards.associate_customer
      gift_cards.cash_out
      gift_cards.recover_print
    ].freeze

    STORE_MANAGER_PHASE3 = %w[
      inventory.view
      inventory.adjust
      inventory.reverse_adjustment
    ].freeze

    STORE_MANAGER_PHASE4 = %w[
      store_taxes.view
      store_taxes.create
      store_taxes.update
      store_taxes.deactivate
      pos.transact
      pos.sessions.view
      pos.price_override.perform
      pos.price_override.approve
      pos.line_discount.perform
      pos.line_discount.approve
      pos.tax_class_override.perform
      pos.tax_class_override.approve
      pos.unlinked_return.perform
      pos.unlinked_return.approve
      pos.post_void.perform
      pos.post_void.approve
    ].freeze

    STORE_MANAGER_PHASE7 = %w[
      suppliers.view
      suppliers.manage
      customers.view
      customers.manage
      customer_requests.manage
      customer_requests.locate
      customer_requests.pickup
      orders.view
      orders.manage
      purchase_orders.send
      purchase_orders.cancel
      purchase_receipts.view
      purchase_receipts.manage
      purchase_receipts.post
      purchase_receipts.backdate
      purchase_receipts.correct
      purchase_receipts.compensate
    ].freeze

    ROLES = [
      {
        key: "system_administrator",
        name: "System administrator",
        assignment_scope: "global",
        permission_keys: PERMISSIONS.map { |p| p[:key] }
      },
      {
        key: "store_manager",
        name: "Store manager",
        assignment_scope: "store",
        permission_keys: %w[
          stores.view
          stores.manage
          registers.view
          registers.create
          registers.manage
          registers.deactivate
          audit_events.view
        ] + STORE_MANAGER_PHASE2_VIEWS + STORE_MANAGER_PHASE3 + STORE_MANAGER_PHASE4 + STORE_MANAGER_PHASE7 + STORE_MANAGER_PHASE9_VIEWS + STORE_MANAGER_PHASE10
      },
      {
        key: "associate",
        name: "Associate",
        assignment_scope: "store",
        permission_keys: %w[
          stores.view
          merchandise.lookup
          products.view
          product_variants.view
          product_forms.view
          subject_schemes.view
          subject_headings.view
          inventory.view
          suppliers.view
          customers.view
          customers.manage
          customer_requests.manage
          customer_requests.locate
          customer_requests.pickup
          orders.view
          orders.manage
          purchase_orders.send
          purchase_orders.cancel
          purchase_receipts.view
          purchase_receipts.manage
          purchase_receipts.post
          pos.transact
          pos.price_override.perform
          pos.line_discount.perform
          pos.tax_class_override.perform
          pos.unlinked_return.perform
          pos.post_void.perform
        ]
      }
    ].freeze

    def seed!(granted_by:)
      PERMISSIONS.each do |attrs|
        Permission.find_or_initialize_by(key: attrs[:key]).tap do |permission|
          permission.assign_attributes(attrs.merge(active: true))
          permission.save!
        end
      end

      ensure_deprecated_revoke_permission!

      ROLES.each do |role_attrs|
        role = Role.find_or_initialize_by(key: role_attrs[:key])
        role.assign_attributes(
          name: role_attrs[:name],
          assignment_scope: role_attrs[:assignment_scope],
          system_role: true,
          active: true
        )
        role.save!

        desired = role_attrs[:permission_keys]
        current = role.permissions.pluck(:key)
        (desired - current).each do |key|
          role.role_permissions.create!(permission: Permission.find_by!(key: key), granted_by: granted_by)
        end
        (current - desired).each do |key|
          role.role_permissions.joins(:permission).where(permissions: { key: key }).find_each(&:destroy!)
        end
      end
    end

    def ensure_deprecated_revoke_permission!
      Permission.find_or_initialize_by(key: "workstations.revoke").tap do |permission|
        permission.assign_attributes(
          group_key: "workstations",
          name: "Revoke workstations (deprecated)",
          scope_type: "either",
          active: false
        )
        permission.save!
      end
    end
  end
end
