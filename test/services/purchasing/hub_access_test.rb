# frozen_string_literal: true

require "test_helper"

class Purchasing::HubAccessTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @admin = @bootstrap[:administrator]
    @store = @bootstrap[:store]
  end

  test "permission_allowed_anywhere evaluates one set per scope and stops early" do
    stores = Array.new(5) do |i|
      Store.create!(
        store_number: (10 + i).to_s,
        code: "hub_perf_#{i}_#{SecureRandom.hex(2)}",
        name: "Hub Perf #{i}",
        legal_name: "Example Books LLC",
        timezone: "America/New_York",
        country_code: "US"
      )
    end

    role = Role.create!(
      key: "hub_recv_#{SecureRandom.hex(3)}",
      name: "Hub receiving",
      assignment_scope: "store",
      system_role: false,
      active: true
    )
    RolePermission.create!(
      role: role,
      permission: Permission.find_by!(key: "purchase_receipts.manage"),
      granted_by: @admin
    )
    user = User.create!(
      username: "hub_perf_#{SecureRandom.hex(3)}",
      display_name: "Hub Perf",
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    # Permission only on the last store — forces scanning global + all stores until match.
    RoleAssignment.create!(
      user: user,
      role: role,
      store: stores.last,
      assigned_by: @admin,
      effective_at: Time.current
    )

    calls = []
    original = Authorization::PermissionEvaluator.method(:permissions_for)
    Authorization::PermissionEvaluator.define_singleton_method(:permissions_for) do |user:, store:|
      calls << store&.id
      original.call(user: user, store: store)
    end

    begin
      assert Purchasing::HubAccess.nav_visible?(user: user, accessible_stores: stores)
      # One global evaluation + one per store until the last (5 stores) = 6 max.
      assert_equal 6, calls.size
      assert_nil calls.first
      assert_equal stores.map(&:id), calls.drop(1)
    ensure
      Authorization::PermissionEvaluator.define_singleton_method(:permissions_for, original)
    end
  end

  test "permission_allowed_anywhere stops after first matching store" do
    first = Store.create!(
      store_number: "21",
      code: "hub_early_#{SecureRandom.hex(2)}",
      name: "Hub Early",
      legal_name: "Example Books LLC",
      timezone: "America/New_York",
      country_code: "US"
    )
    later = Store.create!(
      store_number: "22",
      code: "hub_later_#{SecureRandom.hex(2)}",
      name: "Hub Later",
      legal_name: "Example Books LLC",
      timezone: "America/New_York",
      country_code: "US"
    )

    role = Role.create!(
      key: "hub_early_#{SecureRandom.hex(3)}",
      name: "Hub early",
      assignment_scope: "store",
      system_role: false,
      active: true
    )
    RolePermission.create!(
      role: role,
      permission: Permission.find_by!(key: "orders.view"),
      granted_by: @admin
    )
    user = User.create!(
      username: "hub_early_#{SecureRandom.hex(3)}",
      display_name: "Hub Early User",
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    RoleAssignment.create!(
      user: user,
      role: role,
      store: first,
      assigned_by: @admin,
      effective_at: Time.current
    )

    calls = []
    original = Authorization::PermissionEvaluator.method(:permissions_for)
    Authorization::PermissionEvaluator.define_singleton_method(:permissions_for) do |user:, store:|
      calls << store&.id
      original.call(user: user, store: store)
    end

    begin
      assert Purchasing::HubAccess.nav_visible?(user: user, accessible_stores: [ first, later ])
      assert_equal [ nil, first.id ], calls
    ensure
      Authorization::PermissionEvaluator.define_singleton_method(:permissions_for, original)
    end
  end
end
