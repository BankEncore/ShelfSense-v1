# frozen_string_literal: true

require "test_helper"

class Authorization::PermissionEvaluatorTest < ActiveSupport::TestCase
  setup do
    @bootstrap = Installation::Bootstrap.call(
      organization_name: "Example Books",
      store_number: "1",
      store_code: "main",
      store_name: "Main Store",
      store_timezone: "America/New_York",
      store_country_code: "US",
      admin_username: "admin",
      admin_display_name: "Admin User",
      admin_password: "correct-horse-battery"
    )
    @store = @bootstrap[:store]
    @second_store = Store.create!(
      store_number: "2",
      code: "east",
      name: "East Store",
      timezone: "America/New_York",
      country_code: "US"
    )
    @manager = User.create!(
      username: "manager",
      display_name: "Manager",
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    RoleAssignment.create!(
      user: @manager,
      role: Role.find_by!(key: "store_manager"),
      store: @store,
      assigned_by: @bootstrap[:administrator],
      effective_at: Time.current
    )
  end

  test "accessible stores come from role assignments not stores.view" do
    stores = Authorization::StoreAccess.accessible_stores_for(@manager)
    assert_equal [ @store.id ], stores.map(&:id)

    admin_stores = Authorization::StoreAccess.accessible_stores_for(@bootstrap[:administrator])
    assert_includes admin_stores.map(&:id), @store.id
    assert_includes admin_stores.map(&:id), @second_store.id
  end

  test "store manager permissions apply only in assigned store" do
    at_store = Authorization::PermissionEvaluator.permissions_for(user: @manager, store: @store)
    assert_includes at_store, "workstations.manage"
    assert_includes at_store, "stores.manage"
    assert_not_includes at_store, "users.manage"

    other = Authorization::PermissionEvaluator.permissions_for(user: @manager, store: @second_store)
    assert_empty other
  end

  test "global admin has organization-wide permissions" do
    keys = Authorization::PermissionEvaluator.permissions_for(user: @bootstrap[:administrator], store: @store)
    assert_includes keys, "system_settings.manage"
    assert_includes keys, "users.assign_roles"
    assert_includes keys, "workstations.manage"
  end

  test "store-scoped audit viewers cannot see null-store events" do
    org_event = AuditEvent.create!(
      occurred_at: Time.current,
      recorded_at: Time.current,
      created_at: Time.current,
      actor_type: "system",
      actor_label: "System",
      action: "installation.completed",
      outcome: "succeeded",
      correlation_id: SecureRandom.uuid_v7,
      metadata: {},
      store_id: nil
    )
    store_event = AuditEvent.create!(
      occurred_at: Time.current,
      recorded_at: Time.current,
      created_at: Time.current,
      actor_type: "user",
      actor_user: @manager,
      actor_label: @manager.display_name,
      action: "workstations.create",
      outcome: "succeeded",
      correlation_id: SecureRandom.uuid_v7,
      metadata: {},
      store: @store
    )

    visible_ids = AuditEvent.where(store_id: Authorization::StoreAccess.accessible_stores_for(@manager).select(:id)).pluck(:id)
    assert_includes visible_ids, store_event.id
    assert_not_includes visible_ids, org_event.id
  end
end
