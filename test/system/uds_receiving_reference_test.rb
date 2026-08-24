# frozen_string_literal: true

require "application_system_test_case"

class UdsReceivingReferenceTest < ApplicationSystemTestCase
  setup do
    bootstrap = bootstrap!
    @store = bootstrap[:store]
    @actor = bootstrap[:administrator]
    tax = tax_class(code: "uds_recv_#{SecureRandom.hex(3)}")
    @variant = pos_sellable_variant(actor: @actor, tax_class: tax, name: "UDS Receiving Book")
    @supplier = Supplier.create!(name: "UDS Receiving Supplier", code: "uds_r_#{SecureRandom.hex(3)}")
    SupplierVariantSource.create!(
      supplier: @supplier,
      product_variant: @variant,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 725,
      organization_preferred: true
    )
    sent_po = Purchasing::CreateStockOrder.call(
      store: @store,
      product_variant: @variant,
      actor: @actor,
      quantity: 1
    ).purchase_order
    Purchasing::GeneratePurchaseOrder.call(purchase_order: sent_po, actor: @actor)
    Purchasing::SendPurchaseOrder.call(
      purchase_order: sent_po.reload,
      actor: @actor,
      transmission_method: "email"
    )
    @receipt = Purchasing::CreateDraftPurchaseReceipt.call(store: @store, supplier: @supplier, actor: @actor)

    @dialog_supplier = Supplier.create!(name: "UDS Dialog Supplier", code: "uds_d_#{SecureRandom.hex(3)}")
    tax_dialog = tax_class(code: "uds_dlg_#{SecureRandom.hex(3)}")
    @dialog_variant = pos_sellable_variant(actor: @actor, tax_class: tax_dialog, name: "UDS Dialog Book")
    SupplierVariantSource.create!(
      supplier: @dialog_supplier,
      product_variant: @dialog_variant,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 825,
      organization_preferred: true
    )
    @purchase_order = Purchasing::CreateStockOrder.call(
      store: @store,
      product_variant: @dialog_variant,
      actor: @actor,
      quantity: 1,
      supplier: @dialog_supplier
    ).purchase_order
    Purchasing::GeneratePurchaseOrder.call(purchase_order: @purchase_order, actor: @actor)
    sign_in_admin(actor: @actor)
  end

  test "receiving workspace passes axe and layout smoke" do
    visit ops_receiving_path(@receipt)
    assert_field "receiving_lookup"
    assert_axe_clean(surface: :receiving)
    uds_layout_smoke(surface: :receiving, scroll_selector: ".table-scroll", layout_options: { check_clipped: false })
    assert_reduced_motion_smoke(surface: :receiving)
    assert_forced_colors_smoke(surface: :receiving)
  end

  test "receiving scan workflow restores lookup focus" do
    visit ops_receiving_path(@receipt)
    lookup = find("input[name='receiving_lookup']")
    assert_equal "receiving_lookup", page.evaluate_script("document.activeElement && document.activeElement.name")

    lookup.fill_in with: @variant.sku
    lookup.send_keys :enter
    click_on "Confirm and add line"
    assert_text "Line added. Scanner ready."
    assert_equal "receiving_lookup", page.evaluate_script("document.activeElement && document.activeElement.name")
  end

  test "draft PO send review dialog satisfies shared contract" do
    visit ops_purchase_order_path(@purchase_order.reload)
    assert_review_dialog_contract(
      trigger_label: "Review send",
      submit_label: "Send PO and freeze snapshots",
      initial_focus_name: "transmission_method",
      unchanged: -> {
        assert @purchase_order.reload.generated?
        assert_equal "draft", @purchase_order.status
      },
      prepare_valid: -> { select "email", from: "Transmission method" },
      assert_success: -> {
        assert_text "Purchase order sent"
        assert_equal "sent", @purchase_order.reload.status
      }
    )
  end
end
