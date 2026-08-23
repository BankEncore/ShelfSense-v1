# frozen_string_literal: true

require "test_helper"

class AdminNavigationPrototypeTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @admin = @bootstrap[:administrator]
    @store = @bootstrap[:store]
  end

  test "profile A admin sees all eight groups and store-gated links with store selected" do
    second = Store.create!(
      store_number: "2",
      code: "nav_proto_east",
      name: "East Nav Store",
      legal_name: "Example Books LLC",
      timezone: "America/New_York",
      country_code: "US"
    )

    sign_in_as("admin")
    post store_selection_path, params: { store_id: @store.id }

    get admin_navigation_prototype_path
    assert_response :success
    assert_match(/aria-label="Primary"/, response.body)
    %w[Merchandise Inventory Purchasing Customers POS\ operations Organization\ configuration Security Audit].each do |label|
      assert_match(/#{Regexp.escape(label)}/, response.body)
    end
    assert_match admin_purchasing_path, response.body
    assert_match ops_receiving_index_path, response.body
    assert_match ops_location_path, response.body
    assert_match ops_draft_pos_path, response.body
    assert_match pos_path, response.body
    assert_match pos_transactions_path, response.body
    assert_match(/Switch store/, response.body)

    get admin_navigation_prototype_path(as_controller: "admin/products")
    assert_response :success
    assert_match(/aria-current="page"/, response.body)
    assert_match(/Current area/, response.body)
    assert_match(/is-current-area/, response.body)
  end

  test "profile A without store omits store-gated operational links" do
    Store.create!(
      store_number: "3",
      code: "nav_proto_west",
      name: "West Nav Store",
      legal_name: "Example Books LLC",
      timezone: "America/New_York",
      country_code: "US"
    )

    sign_in_as("admin")
    # Two accessible stores and no selected store => current_store nil
    get admin_navigation_prototype_path
    assert_response :success
    assert_match admin_purchasing_path, response.body
    assert_match admin_orders_path, response.body
    assert_no_match(%r{href="#{Regexp.escape(ops_receiving_index_path)}"}, response.body)
    assert_no_match(%r{href="#{Regexp.escape(ops_location_path)}"}, response.body)
    assert_no_match(%r{href="#{Regexp.escape(ops_draft_pos_path)}"}, response.body)
    assert_no_match(%r{href="#{Regexp.escape(pos_path)}"}, response.body)
  end

  test "profile B receiving-only user sees purchasing hub and receiving ops" do
    role = Role.create!(
      key: "nav_recv_#{SecureRandom.hex(3)}",
      name: "Nav receiving only",
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
      username: "nav_recv_#{SecureRandom.hex(3)}",
      display_name: "Nav Receiving",
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

    post session_path, params: { session: { username: user.username, password: "correct-horse-battery" } }
    post store_selection_path, params: { store_id: @store.id }

    get admin_navigation_prototype_path(as_controller: "ops/receiving")
    assert_response :success
    assert_match(/Purchasing/, response.body)
    assert_match admin_purchasing_path, response.body
    assert_match ops_receiving_index_path, response.body
    assert_no_match admin_orders_path, response.body
    assert_no_match admin_suppliers_path, response.body
    assert_no_match admin_users_path, response.body
    assert_no_match(/Switch store/, response.body)
    assert_match(/Current area/, response.body)

    get admin_orders_path
    assert_redirected_to root_path
  end

  test "profile B without store keeps hub and omits receiving ops" do
    second = Store.create!(
      store_number: "4",
      code: "nav_recv_other_#{SecureRandom.hex(2)}",
      name: "Other Recv Store",
      legal_name: "Example Books LLC",
      timezone: "America/New_York",
      country_code: "US"
    )
    role = Role.create!(
      key: "nav_recv2_#{SecureRandom.hex(3)}",
      name: "Nav receiving multi",
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
      username: "nav_recv2_#{SecureRandom.hex(3)}",
      display_name: "Nav Receiving Multi",
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    [ @store, second ].each do |store|
      RoleAssignment.create!(
        user: user,
        role: role,
        store: store,
        assigned_by: @admin,
        effective_at: Time.current
      )
    end

    post session_path, params: { session: { username: user.username, password: "correct-horse-battery" } }
    # Multiple accessible stores and no selection => no current_store
    get admin_navigation_prototype_path
    assert_response :success
    assert_match(/No store selected/, response.body)
    assert_match admin_purchasing_path, response.body
    assert_no_match(%r{href="#{Regexp.escape(ops_receiving_index_path)}"}, response.body)
  end

  test "user with no destinations is denied the prototype" do
    role = Role.create!(
      key: "nav_none_#{SecureRandom.hex(3)}",
      name: "No destinations",
      assignment_scope: "store",
      system_role: false,
      active: true
    )
    # inventory.view is a destination — use a permission that is NOT in the catalog
    RolePermission.create!(
      role: role,
      permission: Permission.find_by!(key: "pos.sessions.view"),
      granted_by: @admin
    )
    user = User.create!(
      username: "nav_none_#{SecureRandom.hex(3)}",
      display_name: "Nav None",
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

    post session_path, params: { session: { username: user.username, password: "correct-horse-battery" } }
    get admin_navigation_prototype_path
    assert_redirected_to root_path
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end
end
