# frozen_string_literal: true

module Admin
  # Fixed destination inventory for grouped administrative navigation (UDS-4.0+).
  # Paths and matchers are evaluated at request time via Admin::NavigationViewModel.
  class NavigationCatalog
    Group = Data.define(:key, :label, :destinations)
    Destination = Data.define(
      :key,
      :label,
      :path_method,
      :path_args,
      :permission,
      :requires_store,
      :controllers,
      :hub
    )

    class << self
      def groups
        @groups ||= build_groups
      end

      def destinations
        groups.flat_map(&:destinations)
      end

      private

      def dest(key, label, path_method, permission: nil, requires_store: false, controllers: [], hub: false, path_args: [])
        Destination.new(
          key: key,
          label: label,
          path_method: path_method,
          path_args: path_args,
          permission: permission,
          requires_store: requires_store,
          controllers: controllers,
          hub: hub
        )
      end

      def build_groups
        [
          Group.new(
            key: :merchandise,
            label: "Merchandise",
            destinations: [
              dest(:departments, "Departments", :admin_departments_path, permission: "departments.view", controllers: %w[admin/departments]),
              dest(:merchandise_classes, "Merchandise classes", :admin_merchandise_classes_path, permission: "merchandise_classes.view", controllers: %w[admin/merchandise_classes]),
              dest(:merchandise_categories, "Categories", :admin_merchandise_categories_path, permission: "merchandise_categories.view", controllers: %w[admin/merchandise_categories]),
              dest(:merchandise_conditions, "Conditions", :admin_merchandise_conditions_path, permission: "merchandise_conditions.view", controllers: %w[admin/merchandise_conditions]),
              dest(:product_forms, "Product forms", :admin_product_forms_path, permission: "product_forms.view", controllers: %w[admin/product_forms]),
              dest(:subject_schemes, "Subject schemes", :admin_subject_schemes_path, permission: "subject_schemes.view", controllers: %w[admin/subject_schemes admin/subject_headings]),
              dest(:products, "Products", :admin_products_path, permission: "products.view", controllers: %w[admin/products admin/product_variants admin/supplier_variant_sources admin/store_supplier_source_preferences admin/product_catalog_searches]),
              dest(:merchandise_lookup, "Lookup", :new_admin_merchandise_lookup_path, permission: "merchandise.lookup", controllers: %w[admin/merchandise_lookups]),
              dest(:merchandise_import, "Import", :new_admin_merchandise_import_path, permission: "merchandise.import", controllers: %w[admin/merchandise_imports])
            ]
          ),
          Group.new(
            key: :inventory,
            label: "Inventory",
            destinations: [
              dest(:inventory, "Inventory", :admin_inventory_balances_path, permission: "inventory.view", controllers: %w[admin/inventory_balances admin/inventory_adjustments]),
              dest(:adjustment_reasons, "Adjustment reasons", :admin_adjustment_reasons_path, permission: "inventory.manage_adjustment_reasons", controllers: %w[admin/adjustment_reasons]),
              dest(:inventory_reconcile, "Inventory reconcile", :admin_inventory_reconciliation_path, permission: "inventory.reconcile", controllers: %w[admin/inventory_reconciliations])
            ]
          ),
          Group.new(
            key: :purchasing,
            label: "Purchasing",
            destinations: [
              dest(:purchasing_hub, "Purchasing", :admin_purchasing_path, hub: true, controllers: %w[admin/purchasing]),
              dest(:orders, "Orders", :admin_orders_path, permission: "orders.view", controllers: %w[admin/orders]),
              dest(:purchase_orders, "Purchase orders", :admin_purchase_orders_path, permission: "orders.view", controllers: %w[admin/purchase_orders]),
              dest(:purchase_receipts, "Purchase receipts", :admin_purchase_receipts_path, permission: "purchase_receipts.view", controllers: %w[admin/purchase_receipts]),
              dest(:receiving_ops, "Receiving ops", :ops_receiving_index_path, permission: "purchase_receipts.manage", requires_store: true, controllers: %w[ops/receiving]),
              dest(:suppliers, "Suppliers", :admin_suppliers_path, permission: "suppliers.view", controllers: %w[admin/suppliers]),
              dest(:draft_po_ops, "Draft PO ops", :ops_draft_pos_path, permission: "orders.manage", requires_store: true, controllers: %w[ops/draft_pos])
            ]
          ),
          Group.new(
            key: :customers,
            label: "Customers",
            destinations: [
              dest(:customers, "Customers", :admin_customers_path, permission: "customers.view", controllers: %w[admin/customers admin/stored_value_adjustments]),
              dest(:customer_requests, "Customer requests", :admin_customer_requests_path, permission: "customers.view", controllers: %w[admin/customer_requests]),
              dest(:stored_value_transfers, "Stored-value transfers", :new_admin_stored_value_transfer_path, permission: "stored_value.transfer", controllers: %w[admin/stored_value_transfers]),
              dest(:location_ops, "Location ops", :ops_location_path, permission: "customer_requests.locate", requires_store: true, controllers: %w[ops/locations])
            ]
          ),
          Group.new(
            key: :pos_operations,
            label: "POS operations",
            destinations: [
              dest(:pos, "POS", :pos_path, permission: "pos.transact", requires_store: true, controllers: %w[pos/homes pos/enters pos/workspaces pos/preferred_registers pos/active_sessions pos/session_closes pos/register_closes pos/closed_sessions pos/x_reports pos/reports pos/reporting_period_zs pos/reporting_period_finalizations pos/return_items pos/post_voids pos/completed_transactions]),
              dest(:pos_transactions, "Transactions", :pos_transactions_path, permission: "pos.transact", requires_store: true, controllers: %w[pos/transactions]),
              dest(:tender_types, "Tender types", :admin_tender_types_path, permission: "pos.manage_tender_types", controllers: %w[admin/tender_types])
            ]
          ),
          Group.new(
            key: :organization_configuration,
            label: "Organization configuration",
            destinations: [
              dest(:system_settings, "Settings", :admin_system_settings_path, permission: "system_settings.view", controllers: %w[admin/system_settings]),
              dest(:stored_value_adjustment_reasons, "Stored-value reasons", :admin_stored_value_adjustment_reasons_path, permission: "stored_value.manage_adjustment_reasons", controllers: %w[admin/stored_value_adjustment_reasons]),
              dest(:stores, "Stores", :admin_stores_path, permission: %w[stores.view stores.create], controllers: %w[admin/stores]),
              dest(:gl_accounts, "GL Accounts", :admin_gl_accounts_path, permission: "gl_accounts.view", controllers: %w[admin/gl_accounts]),
              dest(:tax_classes, "Tax Classes", :admin_tax_classes_path, permission: "tax_classes.view", controllers: %w[admin/tax_classes]),
              dest(:store_taxes, "Store taxes", :admin_store_taxes_path, permission: "store_taxes.view", controllers: %w[admin/store_taxes]),
              dest(:registers, "Registers", :admin_registers_path, permission: "registers.view", controllers: %w[admin/registers])
            ]
          ),
          Group.new(
            key: :security,
            label: "Security",
            destinations: [
              dest(:users, "Users", :admin_users_path, permission: "users.view", controllers: %w[admin/users]),
              dest(:roles, "Roles", :admin_roles_path, permission: "roles.view", controllers: %w[admin/roles]),
              dest(:role_assignments, "Role assignments", :admin_role_assignments_path, permission: "users.assign_roles", controllers: %w[admin/role_assignments])
            ]
          ),
          Group.new(
            key: :audit,
            label: "Audit",
            destinations: [
              dest(:audit_events, "Audit events", :admin_audit_events_path, permission: "audit_events.view", controllers: %w[admin/audit_events])
            ]
          )
        ].freeze
      end
    end
  end
end
