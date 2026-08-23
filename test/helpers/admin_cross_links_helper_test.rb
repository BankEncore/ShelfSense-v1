# frozen_string_literal: true

require "test_helper"

class AdminCrossLinksHelperTest < ActionView::TestCase
  setup do
    @bootstrap = bootstrap!
    @admin = @bootstrap[:administrator]
    @store = @bootstrap[:store]
    @product = Products::Create.call(
      attributes: { name: "Cross Link Book", status: "draft" },
      actor: @admin
    )
  end

  test "admin product link present for privileged user and nil when unauthorized" do
    stubs_auth!(user: @admin, permissions: %w[products.view])
    assert_includes admin_product_link(@product), admin_product_path(@product)

    stubs_auth!(user: @admin, permissions: [])
    assert_nil admin_product_link(@product)
    assert_nil admin_product_link(nil)
  end

  test "inventory adjust link evaluates permission against destination store" do
    other = Store.create!(
      store_number: "99",
      code: "xlink_other",
      name: "Other Cross Store",
      legal_name: "Example Books LLC",
      timezone: "America/New_York",
      country_code: "US"
    )
    user = store_scoped_user!(
      username_prefix: "xlink_adj",
      permission_key: "inventory.adjust",
      store: @store
    )
    variant = Struct.new(:id).new(SecureRandom.uuid_v7)

    stubs_auth!(user: user, permissions: Set.new, store: @store)
    html = admin_inventory_adjust_link(store: @store, product_variant: variant)
    assert_match(%r{/admin/inventory_adjustments/new}, html)
    assert_match(/store_id=#{Regexp.escape(@store.id)}/, html)

    assert_nil admin_inventory_adjust_link(store: other, product_variant: variant)
    assert_nil admin_inventory_adjust_link(store: nil, product_variant: variant)
  end

  test "customer request cross link evaluates permission against request store" do
    other = Store.create!(
      store_number: "98",
      code: "xlink_req",
      name: "Request Other Store",
      legal_name: "Example Books LLC",
      timezone: "America/New_York",
      country_code: "US"
    )
    user = store_scoped_user!(
      username_prefix: "xlink_cust",
      permission_key: "customers.view",
      store: @store
    )
    tax = tax_class(code: "xlink_#{SecureRandom.hex(2)}")
    variant = pos_sellable_variant(actor: @admin, tax_class: tax, name: "Cross Link Request Book")
    customer = Customer.create!(display_name: "Cross Link Customer", email: "xlink@example.com")
    open_quantity_stock(store: @store, variant: variant, actor: @admin, quantity: 1)
    open_quantity_stock(store: other, variant: variant, actor: @admin, quantity: 1)

    allowed = Customers::CreateRequest.call(
      store: @store,
      customer: customer,
      product_variant: variant,
      actor: @admin
    )
    denied = Customers::CreateRequest.call(
      store: other,
      customer: customer,
      product_variant: variant,
      actor: @admin
    )

    stubs_auth!(user: user, permissions: Set.new, store: @store)
    assert_includes admin_customer_request_cross_link(allowed), admin_customer_request_path(allowed)
    assert_nil admin_customer_request_cross_link(denied)
  end

  test "permission_allowed_at memoizes repeated permission and store checks" do
    other = Store.create!(
      store_number: "97",
      code: "xlink_memo",
      name: "Memo Cross Store",
      legal_name: "Example Books LLC",
      timezone: "America/New_York",
      country_code: "US"
    )
    stubs_auth!(user: @admin, permissions: Set.new, store: @store)

    calls = 0
    original = Authorization::PermissionEvaluator.method(:allowed?)
    Authorization::PermissionEvaluator.define_singleton_method(:allowed?) do |**kwargs|
      calls += 1
      original.call(**kwargs)
    end

    begin
      3.times { assert permission_allowed_at?("inventory.view", store: @store) }
      assert_equal 1, calls

      assert permission_allowed_at?("inventory.view", store: other)
      assert_equal 2, calls

      assert_not permission_allowed_at?("inventory.view", store: nil)
      assert_equal 2, calls
    ensure
      Authorization::PermissionEvaluator.define_singleton_method(:allowed?, original)
    end
  end

  private

  def store_scoped_user!(username_prefix:, permission_key:, store:)
    role = Role.create!(
      key: "#{username_prefix}_#{SecureRandom.hex(3)}",
      name: "#{username_prefix} role",
      assignment_scope: "store",
      system_role: false,
      active: true
    )
    RolePermission.create!(
      role: role,
      permission: Permission.find_by!(key: permission_key),
      granted_by: @admin
    )
    user = User.create!(
      username: "#{username_prefix}_#{SecureRandom.hex(3)}",
      display_name: username_prefix.to_s.tr("_", " ").capitalize,
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    RoleAssignment.create!(
      user: user,
      role: role,
      store: store,
      assigned_by: @admin,
      effective_at: Time.current
    )
    user
  end

  def stubs_auth!(user:, permissions:, store: nil)
    @current_user = user
    @current_store = store
    @effective_permissions = permissions.is_a?(Set) ? permissions : permissions.to_set
  end

  def current_user
    @current_user
  end

  def current_store
    @current_store
  end

  def effective_permissions
    @effective_permissions || Set.new
  end
end
