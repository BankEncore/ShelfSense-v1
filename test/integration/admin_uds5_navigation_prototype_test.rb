# frozen_string_literal: true

require "test_helper"

class AdminUds5NavigationPrototypeTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @admin = @bootstrap[:administrator]
    @store = @bootstrap[:store]
  end

  test "unsigned-in request is redirected to sign in" do
    get admin_uds5_navigation_prototype_path
    assert_redirected_to new_session_path
  end

  test "production products page does not render the disposable prototype" do
    sign_in_as("admin")
    get admin_products_path
    assert_response :success
    assert_no_match(/uds-5-nav-prototype/, response.body)
    assert_no_match(/UDS-5.0 compact navigation prototype/, response.body)
  end

  test "profile A with store sees live catalog destinations in every variant" do
    add_second_store!

    sign_in_as("admin")
    post store_selection_path, params: { store_id: @store.id }

    get admin_products_path
    assert_response :success
    production = destination_hrefs(response.body, ".app-nav-group__list a")

    %w[expanded disclosures area_row].each do |variant|
      get admin_uds5_navigation_prototype_path(variant: variant, as_controller: "admin/products")
      assert_response :success
      prototype = destination_hrefs(response.body, ".uds-5-nav-prototype a.uds-5-nav-prototype__destination")
      assert_equal production.sort, prototype.sort, "variant #{variant} destination set must match production"
    end

    get admin_uds5_navigation_prototype_path(variant: "expanded", as_controller: "admin/products")
    %w[Merchandise Inventory Purchasing Customers POS\ operations Organization\ configuration Security Audit].each do |label|
      assert_match(/#{Regexp.escape(label)}/, response.body)
    end
    assert_includes response.body, ops_receiving_index_path
    assert_includes response.body, pos_path
    assert_match(/Switch store/, response.body)
    assert_match(/Current area/, response.body)
    assert_match(/aria-current="page"/, response.body)
  end

  test "profile A without store omits store-gated operational links from the prototype" do
    add_second_store!

    sign_in_as("admin")
    get admin_uds5_navigation_prototype_path
    assert_response :success
    assert_includes response.body, admin_purchasing_path
    assert_not_includes destination_hrefs(response.body, ".uds-5-nav-prototype a.uds-5-nav-prototype__destination"), ops_receiving_index_path
    assert_not_includes destination_hrefs(response.body, ".uds-5-nav-prototype a.uds-5-nav-prototype__destination"), pos_path
  end

  test "as_controller simulates current destination without changing the catalog" do
    sign_in_as("admin")
    get admin_uds5_navigation_prototype_path(variant: "expanded", as_controller: "admin/products")
    assert_response :success
    assert_select ".uds-5-nav-prototype a.uds-5-nav-prototype__destination[aria-current=page]", text: "Products"
    assert_select ".uds-5-nav-prototype .is-current-area", text: /Merchandise/

    get admin_uds5_navigation_prototype_path(variant: "expanded", as_controller: "admin/users")
    assert_select ".uds-5-nav-prototype a.uds-5-nav-prototype__destination[aria-current=page]", text: "Users"
    assert_select ".uds-5-nav-prototype .is-current-area", text: /Security/
  end

  test "disclosures keep every destination in the DOM inside native details" do
    sign_in_as("admin")
    get admin_uds5_navigation_prototype_path(variant: "disclosures", as_controller: "admin/products")
    assert_response :success
    assert_select ".uds-5-nav-prototype details", minimum: 7
    assert_select ".uds-5-nav-prototype details[open]", minimum: 1
    assert_includes destination_hrefs(response.body, ".uds-5-nav-prototype details a.uds-5-nav-prototype__destination"), admin_users_path
    assert_includes destination_hrefs(response.body, ".uds-5-nav-prototype details[open] a.uds-5-nav-prototype__destination"), admin_products_path
  end

  test "area row shows current group destinations in the in-flow row" do
    sign_in_as("admin")
    get admin_uds5_navigation_prototype_path(variant: "area_row", as_controller: "admin/products")
    assert_response :success
    assert_select ".uds-5-nav-prototype__area-row a.uds-5-nav-prototype__destination", text: "Products"
    area_hrefs = destination_hrefs(response.body, ".uds-5-nav-prototype__area-row a.uds-5-nav-prototype__destination")
    assert_includes area_hrefs, admin_products_path
    assert_not_includes area_hrefs, admin_users_path
    assert_includes destination_hrefs(response.body, ".uds-5-nav-prototype details a.uds-5-nav-prototype__destination"), admin_users_path
  end

  test "unknown variant falls back to expanded" do
    sign_in_as("admin")
    get admin_uds5_navigation_prototype_path(variant: "sidebar", as_controller: "admin/products")
    assert_response :success
    assert_select ".uds-5-nav-prototype--expanded"
    assert_select ".uds-5-nav-prototype details", count: 0
  end

  test "profile B receiving-only user sees hub and receiving ops on the prototype" do
    role = Role.create!(
      key: "uds5_recv_#{SecureRandom.hex(3)}",
      name: "UDS5 receiving only",
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
      username: "uds5_recv_#{SecureRandom.hex(3)}",
      display_name: "UDS5 Receiving",
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

    get admin_uds5_navigation_prototype_path(variant: "disclosures", as_controller: "ops/receiving")
    assert_response :success
    hrefs = destination_hrefs(response.body, ".uds-5-nav-prototype a.uds-5-nav-prototype__destination")
    assert_includes hrefs, admin_purchasing_path
    assert_includes hrefs, ops_receiving_index_path
    assert_not_includes hrefs, admin_orders_path
    assert_not_includes hrefs, admin_users_path
    assert_no_match(/Switch store/, response.body)
    assert_match(/Current area/, response.body)
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end

  def add_second_store!
    Store.create!(
      store_number: "2",
      code: "uds5_nav_east",
      name: "East UDS5 Store",
      legal_name: "Example Books LLC",
      timezone: "America/New_York",
      country_code: "US"
    )
  end

  def destination_hrefs(html, selector)
    Nokogiri::HTML(html).css(selector).map { |node| node["href"] }.compact
  end
end
