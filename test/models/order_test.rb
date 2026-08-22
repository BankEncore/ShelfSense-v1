# frozen_string_literal: true

require "test_helper"

class OrderTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    @tax = tax_class(code: "ord_m_#{SecureRandom.hex(2)}")
    @variant = pos_sellable_variant(actor: @actor, tax_class: @tax)
    @supplier = Supplier.create!(name: "Model Supp", code: "ms_#{SecureRandom.hex(2)}")
  end

  test "rejects Used variant" do
    used = pos_sellable_variant(actor: @actor, tax_class: @tax, variant_type: "used", name: "Used Order")
    order = Order.new(
      store: @store,
      number: 1,
      product_variant: used,
      supplier: @supplier,
      requested_quantity: 1
    )
    assert_not order.valid?
    assert_includes order.errors[:product_variant_id], "must be a Standard variant"
  end

  test "customer order requires quantity one" do
    customer = Customer.create!(display_name: "Qty")
    request = CustomerRequest.create!(
      store: @store,
      number: StoreDocumentSequence.next_number!(store: @store, document_kind: "customer_request"),
      customer: customer,
      product_variant: @variant,
      requested_quantity: 1,
      status: "special_order_pending"
    )
    order = Order.new(
      store: @store,
      number: 1,
      product_variant: @variant,
      supplier: @supplier,
      customer_request: request,
      requested_quantity: 2
    )
    assert_not order.valid?
    assert_match(/must be 1/, order.errors[:requested_quantity].join)
  end
end
