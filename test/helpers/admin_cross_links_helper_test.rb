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

  test "inventory adjust link requires permission and store" do
    variant = Struct.new(:id).new(SecureRandom.uuid_v7)

    stubs_auth!(user: @admin, permissions: %w[inventory.adjust], store: @store)
    html = admin_inventory_adjust_link(store: @store, product_variant: variant)
    assert_match(%r{/admin/inventory_adjustments/new}, html)
    assert_match(/product_variant_id=#{Regexp.escape(variant.id)}/, html)
    assert_match(/store_id=#{Regexp.escape(@store.id)}/, html)

    stubs_auth!(user: @admin, permissions: %w[inventory.adjust], store: nil)
    assert_nil admin_inventory_adjust_link(store: nil, product_variant: variant)

    stubs_auth!(user: @admin, permissions: [], store: @store)
    assert_nil admin_inventory_adjust_link(store: @store, product_variant: variant)
  end

  private

  def stubs_auth!(user:, permissions:, store: nil)
    @current_user = user
    @current_store = store
    @effective_permissions = permissions.to_set
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
