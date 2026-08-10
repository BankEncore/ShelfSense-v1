# frozen_string_literal: true

module Authorization
  module PermissionCatalog
    module_function

    PERMISSIONS = [
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
      { key: "workstations.view", group_key: "workstations", name: "View workstations", scope_type: "either" },
      { key: "workstations.create", group_key: "workstations", name: "Create workstations", scope_type: "either" },
      { key: "workstations.manage", group_key: "workstations", name: "Manage workstations", scope_type: "either" },
      { key: "workstations.deactivate", group_key: "workstations", name: "Deactivate workstations", scope_type: "either" },
      { key: "workstations.revoke", group_key: "workstations", name: "Revoke workstations", scope_type: "either" },
      { key: "audit_events.view", group_key: "audit_events", name: "View audit events", scope_type: "either" }
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
          workstations.view
          workstations.create
          workstations.manage
          workstations.deactivate
          workstations.revoke
          audit_events.view
        ]
      },
      {
        key: "associate",
        name: "Associate",
        assignment_scope: "store",
        permission_keys: %w[stores.view]
      }
    ].freeze

    def seed!(granted_by:)
      PERMISSIONS.each do |attrs|
        Permission.find_or_initialize_by(key: attrs[:key]).tap do |permission|
          permission.assign_attributes(attrs.merge(active: true))
          permission.save!
        end
      end

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
  end
end
