# frozen_string_literal: true

require "test_helper"

class AdminGroupedNavigationTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @admin = @bootstrap[:administrator]
    @store = @bootstrap[:store]
  end

  test "profile A admin sees all eight groups and store-gated links with store selected" do
    Store.create!(
      store_number: "2",
      code: "nav_prod_east",
      name: "East Nav Store",
      legal_name: "Example Books LLC",
      timezone: "America/New_York",
      country_code: "US"
    )

    sign_in_as("admin")
    post store_selection_path, params: { store_id: @store.id }

    get admin_products_path
    assert_response :success
    assert_match(/aria-label="Primary"/, response.body)
    assert_match(/app-nav--grouped/, response.body)
    assert_select ".app-nav__strip"
    assert_select ".app-nav__wide-groups"
    assert_select ".app-nav__areas"
    assert_select ".app-nav__current-destination a[aria-current=page]", text: "Products"
    assert_select ".app-nav__area-row a[aria-current=page]", text: "Products"
    assert_select ".app-nav-group__heading.is-current-area", text: /Merchandise/
    assert_select ".app-nav__wide-groups details", minimum: 7
    assert_select ".uds-5-nav-prototype", count: 0
    area_hrefs = destination_hrefs(response.body, ".app-nav__area-row a")
    assert_includes area_hrefs, admin_products_path
    assert_not_includes area_hrefs, admin_users_path
    assert_includes destination_hrefs(response.body, ".app-nav__wide-groups details a"), admin_users_path
    assert_includes destination_hrefs(response.body, ".app-nav__areas a"), admin_users_path
    assert_includes destination_hrefs(response.body, ".app-nav__areas a"), admin_products_path
    %w[Merchandise Inventory Purchasing Customers POS\ operations Organization\ configuration Security Audit].each do |label|
      assert_match(/#{Regexp.escape(label)}/, response.body)
    end
    assert_includes response.body, admin_purchasing_path
    assert_includes response.body, admin_orders_path
    assert_includes response.body, admin_purchase_orders_path
    assert_includes response.body, admin_purchase_receipts_path
    assert_includes response.body, ops_receiving_index_path
    assert_includes response.body, ops_location_path
    assert_includes response.body, ops_draft_pos_path
    assert_includes response.body, pos_path
    assert_includes response.body, pos_transactions_path
    assert_match(/Switch store/, response.body)
    assert_includes response.body, "return_to="
    assert_match(/aria-current="page"/, response.body)
    assert_match(/Current area/, response.body)
    assert_match(/is-current-area/, response.body)
  end

  test "profile A keeps store context after second store when sole store was previously used" do
    sign_in_as("admin")
    get admin_products_path
    assert_response :success
    assert_match(/Current store:/, response.body)

    Store.create!(
      store_number: "5",
      code: "nav_prod_late",
      name: "Late Nav Store",
      legal_name: "Example Books LLC",
      timezone: "America/New_York",
      country_code: "US"
    )

    get admin_products_path
    assert_response :success
    assert_match(/Current store:/, response.body)
    assert_includes response.body, ops_receiving_index_path
  end

  test "switch store returns to the referring admin page" do
    Store.create!(
      store_number: "6",
      code: "nav_prod_return",
      name: "Return Nav Store",
      legal_name: "Example Books LLC",
      timezone: "America/New_York",
      country_code: "US"
    )

    sign_in_as("admin")
    return_to = admin_products_path
    post store_selection_path, params: { store_id: @store.id, return_to: return_to }
    assert_redirected_to return_to
    follow_redirect!
    assert_match(/aria-current="page"/, response.body)
  end

  test "profile A without store omits store-gated operational links" do
    Store.create!(
      store_number: "3",
      code: "nav_prod_west",
      name: "West Nav Store",
      legal_name: "Example Books LLC",
      timezone: "America/New_York",
      country_code: "US"
    )

    sign_in_as("admin")
    get admin_products_path
    assert_response :success
    assert_includes response.body, admin_purchasing_path
    assert_includes response.body, admin_orders_path
    assert_not_includes response.body, ops_receiving_index_path
    assert_not_includes response.body, ops_location_path
    assert_not_includes response.body, ops_draft_pos_path
    assert_no_match(%r{href="#{Regexp.escape(pos_path)}"}, response.body)
    assert_no_match(%r{href="#{Regexp.escape(pos_transactions_path)}"}, response.body)
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

    get admin_purchasing_path
    assert_response :success
    assert_match(/app-nav--grouped/, response.body)
    assert_match(/Purchasing/, response.body)
    assert_select ".app-nav__area-row a[aria-current=page]", text: "Purchasing"
    assert_includes response.body, admin_purchasing_path
    assert_includes response.body, ops_receiving_index_path
    assert_includes destination_hrefs(response.body, ".app-nav__area-row a"), ops_receiving_index_path
    assert_not_includes response.body, admin_orders_path
    assert_not_includes response.body, admin_suppliers_path
    assert_not_includes response.body, admin_users_path
    assert_no_match(/Switch store/, response.body)
    assert_match(/Current area/, response.body)

    get admin_orders_path
    assert_redirected_to root_path
  end

  test "retired 5.0 navigation prototype route is gone" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/admin/uds5_navigation_prototype")
    end
  end

  test "retired 5.1 composition prototype route is gone" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/admin/uds5_composition_prototype")
    end
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
    get admin_purchasing_path
    assert_response :success
    assert_includes response.body, admin_purchasing_path
    assert_not_includes response.body, ops_receiving_index_path
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end

  def destination_hrefs(html, selector)
    Nokogiri::HTML(html).css(selector).map { |node| node["href"] }.compact
  end
end
