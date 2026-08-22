# frozen_string_literal: true

require "application_system_test_case"

class PurchasingOpsWorkspaceTest < ApplicationSystemTestCase
  setup do
    bootstrap = bootstrap!
    @store = bootstrap[:store]
    @actor = bootstrap[:administrator]
    tax = tax_class(code: "ops_#{SecureRandom.hex(3)}")
    @variant = pos_sellable_variant(actor: @actor, tax_class: tax, name: "Keyboard Purchasing Book")
    @supplier = Supplier.create!(name: "Keyboard Supplier", code: "key_#{SecureRandom.hex(3)}")
    SupplierVariantSource.create!(
      supplier: @supplier,
      product_variant: @variant,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 725,
      organization_preferred: true
    )
    @purchase_order = Purchasing::CreateStockOrder.call(
      store: @store,
      product_variant: @variant,
      actor: @actor,
      quantity: 1
    ).purchase_order
    sign_in_admin
  end

  test "scan Enter adds repeatedly and restores lookup focus after success and recoverable failure" do
    visit ops_purchase_order_path(@purchase_order)
    lookup = find("input[name='identifier']")
    assert_equal "identifier", page.evaluate_script("document.activeElement && document.activeElement.name")

    lookup.fill_in with: @variant.sku
    lookup.send_keys :enter
    assert_text "Added stock order"
    assert_equal "identifier", page.evaluate_script("document.activeElement && document.activeElement.name")

    find("input[name='identifier']").fill_in with: "not-a-real-identifier"
    find("input[name='identifier']").send_keys :enter
    assert_selector ".flash--alert"
    assert_equal "identifier", page.evaluate_script("document.activeElement && document.activeElement.name")
  end

  test "visible shortcuts focus lookup, save the active row, and invoke the primary action" do
    visit ops_purchase_order_path(@purchase_order)
    assert_button "Focus lookup /"
    assert_button "Save Ctrl/⌘ S"
    assert_button "Primary action Ctrl/⌘ Enter"
    click_on "Shortcut help"
    assert_text "Keyboard shortcuts"
    send_keys :escape
    assert_no_text "Keyboard shortcuts"

    find("input[name='quantity']", match: :first).click
    send_keys [ :control, "s" ]
    assert_text "Line updated"

    find("body").send_keys [ :control, :enter ]
    assert_text "Purchase order generated"
  end

  test "arrow selection, Enter activation, and Escape cancellation do not change a draft" do
    visit ops_purchase_order_path(@purchase_order)
    original_version = @purchase_order.purchase_order_lines.first.order.lock_version

    find("h2", text: "Lines").click
    send_keys :arrow_down
    assert_selector "tr.is-selected"
    send_keys :escape
    assert_no_selector "tr.is-selected"
    assert_equal original_version, @purchase_order.purchase_order_lines.first.order.reload.lock_version

    send_keys :arrow_down
    find("tr.is-selected").send_keys :enter
    assert_text "Line updated"
  end

  test "dirty receipt or PO edits require confirmation before Turbo navigation" do
    visit ops_purchase_order_path(@purchase_order)
    notes = find("input[name='notes']", match: :first)
    notes.fill_in with: "unsaved buyer note"

    dismiss_confirm("Discard unsaved purchasing changes?") do
      click_on "All drafts"
    end
    assert_current_path ops_purchase_order_path(@purchase_order)
    assert_field "notes", with: "unsaved buyer note"

    accept_confirm("Discard unsaved purchasing changes?") do
      click_on "All drafts"
    end
    assert_current_path ops_draft_pos_path
    assert_nil @purchase_order.purchase_order_lines.first.order.reload.notes
  end

  test "receiving scan selects defaults, updates through Turbo, and restores scanner focus" do
    Purchasing::GeneratePurchaseOrder.call(purchase_order: @purchase_order, actor: @actor)
    Purchasing::SendPurchaseOrder.call(purchase_order: @purchase_order.reload, actor: @actor, transmission_method: "email")
    receipt = Purchasing::CreateDraftPurchaseReceipt.call(store: @store, supplier: @supplier, actor: @actor)

    visit ops_receiving_path(receipt)
    lookup = find("input[name='receiving_lookup']")
    assert_equal "receiving_lookup", page.evaluate_script("document.activeElement && document.activeElement.name")
    lookup.fill_in with: @variant.sku
    lookup.send_keys :enter
    assert_field "received_quantity", with: "1"
    assert_field "actual_unit_cost_cents", with: "725"
    click_on "Confirm and add line"

    assert_text "Line added. Scanner ready."
    assert_selector "#receiving_line_grid", text: "Keyboard Purchasing Book"
    assert_equal "receiving_lookup", page.evaluate_script("document.activeElement && document.activeElement.name")
  end

  private

  def sign_in_admin
    visit new_session_path
    fill_in "session_username", with: @actor.username
    fill_in "session_password", with: "correct-horse-battery"
    find_field("session_password").send_keys :enter
    assert_text "Signed in successfully"
  end
end
