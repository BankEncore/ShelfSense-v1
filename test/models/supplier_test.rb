# frozen_string_literal: true

require "test_helper"

class SupplierTest < ActiveSupport::TestCase
  test "normalizes code and rejects changes after create" do
    supplier = Supplier.create!(name: "Ingram Content", code: "Ingram Content")
    assert_equal "ingram_content", supplier.code

    supplier.code = "other"
    assert_not supplier.valid?
    assert_includes supplier.errors[:code], "cannot be changed after creation"
  end

  test "requires unique code and name" do
    Supplier.create!(name: "Baker & Taylor", code: "baker_taylor")
    duplicate = Supplier.new(name: "Other", code: "baker_taylor")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:code], "has already been taken"

    nameless = Supplier.new(code: "nameless")
    assert_not nameless.valid?
    assert_includes nameless.errors[:name], "can't be blank"
  end

  test "cannot deactivate while draft purchase orders exist" do
    bootstrap = bootstrap!
    store = bootstrap[:store]
    actor = bootstrap[:administrator]
    tax = tax_class(code: "sup_#{SecureRandom.hex(2)}")
    variant = pos_sellable_variant(actor: actor, tax_class: tax, name: "Supplier Block")
    supplier = Supplier.create!(name: "Draft Block", code: "db_#{SecureRandom.hex(2)}")
    SupplierVariantSource.create!(
      supplier: supplier,
      product_variant: variant,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 300,
      organization_preferred: true
    )
    Purchasing::CreateStockOrder.call(
      store: store,
      product_variant: variant,
      actor: actor,
      quantity: 1,
      supplier: supplier
    )

    supplier.active = false
    assert_not supplier.valid?
    assert_match(/draft purchase order/i, supplier.errors.full_messages.to_sentence)
    assert supplier.reload.active?
  end

  test "can deactivate after last draft order is reassigned and empty draft is removed" do
    bootstrap = bootstrap!
    store = bootstrap[:store]
    actor = bootstrap[:administrator]
    tax = tax_class(code: "sup3_#{SecureRandom.hex(2)}")
    variant = pos_sellable_variant(actor: actor, tax_class: tax, name: "Supplier Move")
    supplier_a = Supplier.create!(name: "Old Supp", code: "old_#{SecureRandom.hex(2)}")
    supplier_b = Supplier.create!(name: "New Supp", code: "new_#{SecureRandom.hex(2)}")
    SupplierVariantSource.create!(
      supplier: supplier_a,
      product_variant: variant,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 300,
      organization_preferred: true
    )
    SupplierVariantSource.create!(
      supplier: supplier_b,
      product_variant: variant,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 320
    )

    order = Purchasing::CreateStockOrder.call(
      store: store,
      product_variant: variant,
      actor: actor,
      quantity: 1,
      supplier: supplier_a
    )
    old_po_id = order.purchase_order.id

    Purchasing::UpdateDraftOrder.call(
      order: order,
      actor: actor,
      supplier: supplier_b,
      expected_lock_version: order.lock_version
    )

    assert_nil PurchaseOrder.find_by(id: old_po_id)
    assert_equal supplier_b.id, order.reload.supplier_id
    assert supplier_a.update(active: false)
    assert_not supplier_a.reload.active?
  end

  test "can deactivate when only sent purchase orders remain" do
    bootstrap = bootstrap!
    store = bootstrap[:store]
    actor = bootstrap[:administrator]
    tax = tax_class(code: "sup2_#{SecureRandom.hex(2)}")
    variant = pos_sellable_variant(actor: actor, tax_class: tax, name: "Supplier Sent")
    supplier = Supplier.create!(name: "Sent Only", code: "so_#{SecureRandom.hex(2)}")
    SupplierVariantSource.create!(
      supplier: supplier,
      product_variant: variant,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 300,
      organization_preferred: true
    )
    order = Purchasing::CreateStockOrder.call(
      store: store,
      product_variant: variant,
      actor: actor,
      quantity: 1,
      supplier: supplier
    )
    po = order.purchase_order
    Purchasing::GeneratePurchaseOrder.call(purchase_order: po, actor: actor)
    Purchasing::SendPurchaseOrder.call(
      purchase_order: po.reload,
      actor: actor,
      transmission_method: "email"
    )

    assert supplier.update(active: false)
    assert_not supplier.reload.active?
  end
end
