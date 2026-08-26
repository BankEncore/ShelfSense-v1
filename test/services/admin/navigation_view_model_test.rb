# frozen_string_literal: true

require "test_helper"

class Admin::NavigationViewModelTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @admin = @bootstrap[:administrator]
    @store = @bootstrap[:store]
  end

  test "profile A with store includes all eight groups and store-gated destinations" do
    permissions = Authorization::PermissionEvaluator.permissions_for(user: @admin, store: @store)
    nav = Admin::NavigationViewModel.new(
      user: @admin,
      permissions: permissions,
      current_store: @store,
      accessible_stores: Store.active.order(:name),
      controller_path: "admin/products"
    )

    assert_equal 8, nav.groups.size
    assert_equal %i[merchandise inventory purchasing customers pos_operations organization_configuration security audit],
                 nav.groups.map(&:key)

    purchasing = nav.groups.find { |g| g.key == :purchasing }
    assert purchasing.destinations.any? { |d| d.key == :purchasing_hub }
    assert purchasing.destinations.any? { |d| d.key == :receiving_ops }
    assert purchasing.destinations.any? { |d| d.key == :draft_po_ops }
    assert nav.groups.find { |g| g.key == :customers }.destinations.any? { |d| d.key == :location_ops }
    assert nav.groups.find { |g| g.key == :customers }.destinations.any? { |d| d.key == :stored_value_transfers }
    assert nav.groups.find { |g| g.key == :organization_configuration }.destinations.any? { |d| d.key == :stored_value_adjustment_reasons }
    assert nav.groups.find { |g| g.key == :pos_operations }.destinations.any? { |d| d.key == :pos }
    assert nav.groups.find { |g| g.key == :pos_operations }.destinations.any? { |d| d.key == :gift_cards }
    assert nav.groups.find { |g| g.key == :pos_operations }.destinations.any? { |d| d.key == :gift_card_programs }
    assert nav.groups.find { |g| g.key == :pos_operations }.destinations.any? { |d| d.key == :stored_value_report }
    assert nav.groups.find { |g| g.key == :pos_operations }.destinations.any? { |d| d.key == :cash_safe }

    assert nav.groups.find { |g| g.key == :merchandise }.current
    assert_equal :products, nav.current_destination.key
    assert nav.current_destination.current
  end

  test "without store omits store-gated destinations but keeps hub and history" do
    permissions = Authorization::PermissionEvaluator.permissions_for(user: @admin, store: nil)
    nav = Admin::NavigationViewModel.new(
      user: @admin,
      permissions: permissions,
      current_store: nil,
      accessible_stores: Store.active.order(:name),
      controller_path: "home"
    )

    purchasing = nav.groups.find { |g| g.key == :purchasing }
    assert purchasing.destinations.any? { |d| d.key == :purchasing_hub }
    assert purchasing.destinations.any? { |d| d.key == :orders }
    assert_not purchasing.destinations.any? { |d| d.key == :receiving_ops }
    assert_not purchasing.destinations.any? { |d| d.key == :draft_po_ops }
    assert_not nav.groups.find { |g| g.key == :customers }.destinations.any? { |d| d.key == :location_ops }
    assert_not nav.groups.find { |g| g.key == :pos_operations }.destinations.any? { |d| d.key == :pos }
  end

  test "empty groups are omitted and one-destination groups remain" do
    role = Role.create!(
      key: "audit_only_#{SecureRandom.hex(3)}",
      name: "Audit only",
      assignment_scope: "store",
      system_role: false,
      active: true
    )
    RolePermission.create!(
      role: role,
      permission: Permission.find_by!(key: "audit_events.view"),
      granted_by: @admin
    )
    user = User.create!(
      username: "audit_nav_#{SecureRandom.hex(3)}",
      display_name: "Audit Nav",
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    RoleAssignment.create!(
      user: user,
      role: role,
      store: @store,
      assigned_by: @admin,
      effective_at: Time.current
    )

    permissions = Authorization::PermissionEvaluator.permissions_for(user: user, store: @store)
    nav = Admin::NavigationViewModel.new(
      user: user,
      permissions: permissions,
      current_store: @store,
      accessible_stores: [ @store ],
      controller_path: "admin/audit_events"
    )

    assert_equal [ :audit ], nav.groups.map(&:key)
    assert_equal [ :audit_events ], nav.groups.first.destinations.map(&:key)
    assert nav.groups.first.current
    assert nav.current_destination.current
  end

  test "stores destination allows stores.view or stores.create" do
    role = Role.create!(
      key: "store_create_#{SecureRandom.hex(3)}",
      name: "Store create",
      assignment_scope: "global",
      system_role: false,
      active: true
    )
    RolePermission.create!(
      role: role,
      permission: Permission.find_by!(key: "stores.create"),
      granted_by: @admin
    )
    user = User.create!(
      username: "store_create_#{SecureRandom.hex(3)}",
      display_name: "Store Create",
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    RoleAssignment.create!(
      user: user,
      role: role,
      store: nil,
      assigned_by: @admin,
      effective_at: Time.current
    )

    permissions = Authorization::PermissionEvaluator.permissions_for(user: user, store: nil)
    nav = Admin::NavigationViewModel.new(
      user: user,
      permissions: permissions,
      current_store: nil,
      accessible_stores: Store.none,
      controller_path: "admin/stores"
    )

    org = nav.groups.find { |g| g.key == :organization_configuration }
    assert org
    assert org.destinations.any? { |d| d.key == :stores }
  end
end
