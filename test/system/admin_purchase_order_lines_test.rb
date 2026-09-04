# frozen_string_literal: true

require "application_system_test_case"

class AdminPurchaseOrderLinesTest < ApplicationSystemTestCase
  setup do
    bootstrap = bootstrap!
    @store = bootstrap[:store]
    @actor = bootstrap[:administrator]
    tax = tax_class(code: "admin_po_ui_#{SecureRandom.hex(3)}")
    @supplier = Supplier.create!(name: "Admin PO UI Supplier", code: "po_ui_#{SecureRandom.hex(3)}")
    @variant = pos_sellable_variant(actor: @actor, tax_class: tax, name: "Dialog Focus Book")
    SupplierVariantSource.create!(
      supplier: @supplier,
      product_variant: @variant,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 425,
      organization_preferred: true
    )
    first = Purchasing::CreateStockOrder.call(
      store: @store, product_variant: @variant, actor: @actor, quantity: 2, supplier: @supplier
    )
    second_variant = pos_sellable_variant(actor: @actor, tax_class: tax, name: "Responsive Table Book")
    SupplierVariantSource.create!(
      supplier: @supplier,
      product_variant: second_variant,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 550
    )
    Purchasing::CreateStockOrder.call(
      store: @store, product_variant: second_variant, actor: @actor, quantity: 1, supplier: @supplier
    )
    @purchase_order = first.purchase_order
    Purchasing::GeneratePurchaseOrder.call(purchase_order: @purchase_order, actor: @actor)
    Purchasing::SendPurchaseOrder.call(
      purchase_order: @purchase_order.reload, actor: @actor, transmission_method: "email"
    )
    @line = first.purchase_order_line.reload
    sign_in_admin(actor: @actor)
    visit admin_purchase_order_path(@purchase_order)
  end

  test "line dialogs restore focus and stale acknowledgment recovery focuses the affected form" do
    line_row = find("#purchase-order-line-#{@line.id}")
    trigger = line_row.find_button("Review cancellation")
    trigger.click
    assert_selector "#cancellation-dialog-#{@line.id}", visible: true
    click_button "Keep original open quantity"
    assert_equal trigger.native, page.driver.browser.switch_to.active_element

    line_row.find_button("Edit acknowledgment").click
    dialog = find("#acknowledgment-dialog-#{@line.id}", visible: true)
    stale_version = @line.line_state.reload.lock_version
    @line.line_state.update!(notes: "Concurrent buyer note")
    within(dialog) do
      fill_in "Confirmed quantity", with: 1
      click_button "Save acknowledgment"
    end

    assert_text "This acknowledgment was changed by someone else"
    assert_selector "#acknowledgment-dialog-#{@line.id}", visible: true
    assert_equal "confirmed_quantity", page.evaluate_script("document.activeElement && document.activeElement.name")
    refute_equal stale_version.to_s, find("#acknowledgment-dialog-#{@line.id} input[name='lock_version']", visible: false).value
  end

  test "line table remains contained and horizontally scrollable at a narrow viewport" do
    with_viewport(width: 320, height: 568) do
      region = find(".purchase-order-lines .table-scroll")
      dimensions = page.evaluate_script(<<~JS, region.native)
        (function(region) {
          return {
            regionClient: region.clientWidth,
            regionScroll: region.scrollWidth,
            pageClient: document.documentElement.clientWidth,
            pageScroll: document.documentElement.scrollWidth
          }
        })(arguments[0])
      JS
      assert_operator dimensions["regionScroll"], :>, dimensions["regionClient"]
      assert_operator dimensions["pageScroll"], :<=, dimensions["pageClient"] + 1
      assert_selector "table.purchase-order-lines__table tbody tr[data-purchase-order-line-id]", count: 2
    end
  end
end
