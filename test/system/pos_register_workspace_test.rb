# frozen_string_literal: true

require "application_system_test_case"

class PosRegisterWorkspaceTest < ApplicationSystemTestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    @tax = tax_class(code: "physical_book", name: "Physical book")
    StoreTaxes::Create.call(
      store: @store,
      actor: @actor,
      name: "Illinois State",
      rate_percent: "5.000",
      calculation_order: 1,
      applies_by_tax_class_id: { @tax.id => true }
    )
    @variant = pos_sellable_variant(actor: @actor, tax_class: @tax)
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 5)
    @register = Register.create!(store: @store, register_number: 1, name: "Front")
  end

  test "cashier can sell cash and start a new sale from the receipt" do
    open_register
    add_current_sku
    field = find("#pos-command-field")
    field.fill_in with: @variant.sku
    field.send_keys :enter
    assert_selector "tr.is-selected[data-quantity='2']"
    assert_text "SALE ENTRY"

    click_on "Tender (+)"
    assert_text "CASH TENDER"
    field = find("#pos-command-field")
    field.fill_in with: "50.00"
    field.send_keys :enter
    send_keys :enter

    assert_text "Transaction complete", wait: 10
    assert_equal 1, PosTransaction.completed.where(register: @register).count
    assert_text "New transaction"
    send_keys :enter
    assert_text "Transaction complete"
    click_on "New transaction"
    assert_text "SALE ENTRY"
    assert_no_text "Example Book"
  end

  test "cashier can take Card then Cash and return to sale abandons working tenders" do
    open_register
    add_current_sku
    click_on "Tender (+)"
    assert_text "CASH TENDER"
    assert_no_selector "[data-register-workspace-target='referenceWrap']", visible: true
    send_keys :f2
    assert_selector "[data-register-workspace-target='fieldLabel']", text: /External Card/
    assert_selector "[data-register-workspace-target='referenceWrap']", visible: true
    assert_field "Reference (optional)"
    field = find("#pos-command-field")
    field.fill_in with: "10.00"
    field.send_keys :enter
    assert_selector ".pos-totals", text: "External Card"
    assert_text "Amount due"
    assert_equal "pos-command-field", page.evaluate_script("document.activeElement && document.activeElement.id")
    click_on "Return to sale"
    assert_text "SALE ENTRY"
    assert_no_selector ".pos-totals", text: "External Card"

    click_on "Tender (+)"
    send_keys :f2
    assert_selector "[data-register-workspace-target='fieldLabel']", text: /External Card/
    field = find("#pos-command-field")
    field.fill_in with: "10.00"
    field.send_keys :enter
    assert_selector ".pos-totals", text: "External Card"
    assert_text "Amount due"
    field = find("#pos-command-field")
    field.send_keys :f1
    assert_selector "[data-register-workspace-target='fieldLabel']", text: /Cash presented/
    field = find("#pos-command-field")
    field.fill_in with: "50.00"
    field.send_keys :enter
    send_keys :enter

    assert_text "Transaction complete", wait: 10
    assert_text "External Card"
    assert_text "Cash"
    completed = PosTransaction.completed.find_by!(register: @register)
    assert_equal %w[card cash], completed.pos_tenders.ordered.map(&:behavioral_category)
  end

  test "delete and hyphen edit the identifier and f8 removes the selected line" do
    open_register
    field = find("#pos-command-field")
    field.fill_in with: "ABC"
    field.send_keys :left, :left, :delete
    assert_equal "AC", field.value

    sku = @variant.sku.to_s
    hyphenated = sku.length > 3 ? "#{sku[0..2]}-#{sku[3..]}" : "#{sku}-"
    field.fill_in with: hyphenated
    field.send_keys :enter
    assert_text "Example Book"
    field = find("#pos-command-field")
    field.fill_in with: "978-0-14"
    assert_equal "978-0-14", field.value
    assert_text "Example Book"
    field.fill_in with: ""
    field.send_keys :f8
    assert_no_text "Example Book"
  end

  test "enter in approver username does not apply an override" do
    pos_transacting_user(store: @store, assigned_by: @actor, username: "clerk_scan")
    pos_store_manager(store: @store, assigned_by: @actor, username: "mgr_scan")
    visit new_session_path
    fill_in "session_username", with: "clerk_scan"
    fill_in "session_password", with: "correct-horse-battery"
    find_field("session_password").send_keys :enter
    assert_text "Signed in successfully"
    visit pos_register_enter_path(register_id: @register.id)
    fill_in "Opening float", with: "0.00"
    click_on "Open register"
    assert_text "SALE ENTRY"
    add_current_sku

    click_on "Price (F6)"
    assert_selector "#pos_control_overlay", visible: true
    fill_in "Selling price", with: "15.00"
    select "Damaged", from: "Reason"
    find("#pos-control-price").send_keys :enter

    assert_selector "#pos_control_overlay", visible: true
    assert_equal "pos-approver-username", page.evaluate_script("document.activeElement && document.activeElement.id")
    line = PosTransaction.working.find_by!(register: @register).pos_transaction_lines.first
    assert_equal line.reference_unit_price_cents, line.selling_unit_price_cents

    username = find("#pos-approver-username")
    username.fill_in with: "mgr_scan"
    username.send_keys :enter

    assert_selector "#pos_control_overlay", visible: true
    assert_equal "pos-approver-password", page.evaluate_script("document.activeElement && document.activeElement.id")
    line.reload
    assert_equal line.reference_unit_price_cents, line.selling_unit_price_cents
  end

  test "rejected approver credentials stay in the price overlay" do
    pos_transacting_user(store: @store, assigned_by: @actor, username: "clerk_retry")
    pos_store_manager(store: @store, assigned_by: @actor, username: "mgr_retry")
    visit new_session_path
    fill_in "session_username", with: "clerk_retry"
    fill_in "session_password", with: "correct-horse-battery"
    find_field("session_password").send_keys :enter
    assert_text "Signed in successfully"
    visit pos_register_enter_path(register_id: @register.id)
    fill_in "Opening float", with: "0.00"
    click_on "Open register"
    assert_text "SALE ENTRY"
    add_current_sku

    click_on "Price (F6)"
    assert_selector "#pos_control_overlay", visible: true
    fill_in "Selling price", with: "15.00"
    select "Damaged", from: "Reason"
    fill_in "Approver username", with: "mgr_retry"
    find("#pos-approver-password").fill_in with: "typoooo"
    find("#pos-approver-password").send_keys :enter

    assert_selector "#pos_control_overlay", visible: true
    assert_selector "#pos-control-feedback", text: /approver credentials/
    assert_field "Selling price", with: "15.00"
    assert_field "Approver username", with: "mgr_retry"
    assert_equal "", find("#pos-approver-password").value
    assert_equal "pos-approver-password", page.evaluate_script("document.activeElement && document.activeElement.id")
    line = PosTransaction.working.find_by!(register: @register).pos_transaction_lines.first
    assert_equal line.reference_unit_price_cents, line.selling_unit_price_cents

    find("#pos-approver-password").fill_in with: "correct-horse-battery"
    find("#pos-approver-password").send_keys :enter
    assert_no_selector "#pos_control_overlay", visible: true
    assert_equal 1500, line.reload.selling_unit_price_cents
  end

  test "enter from a direct price field applies the override" do
    open_register
    add_current_sku

    click_on "Price (F6)"
    assert_selector "#pos_control_overlay", visible: true
    fill_in "Selling price", with: "15.00"
    select "Damaged", from: "Reason"
    find("#pos-control-price").send_keys :enter

    assert_no_selector "#pos_control_overlay", visible: true
    line = PosTransaction.working.find_by!(register: @register).pos_transaction_lines.first
    assert_equal 1500, line.selling_unit_price_cents
  end

  test "blocking overlay panel is an opaque surface above the dimmed workspace" do
    open_register
    add_current_sku

    click_on "Price (F6)"
    assert_selector "#pos_control_overlay", visible: true
    background = page.evaluate_script(<<~JS)
      getComputedStyle(document.querySelector("#pos_control_overlay .pos-overlay__panel")).backgroundColor
    JS
    assert_match(/rgb\(\s*255,\s*255,\s*255\s*\)/, background)
    refute_match(/rgba\(\s*0,\s*0,\s*0,\s*0\s*\)/, background)
  end

  test "f5 opens stored-value tenders and f6 and f7 open controlled-action overlays" do
    open_register
    add_current_sku

    send_keys :f5
    assert_selector "#pos_other_overlay", visible: true
    assert_selector "#pos_other_overlay li", text: "Gift card"
    send_keys :escape
    assert_no_selector "#pos_other_overlay", visible: true

    send_keys :f6
    assert_selector "#pos_control_overlay", visible: true
    assert_selector "#pos-control-title", text: "Price override"
    send_keys :escape
    assert_no_selector "#pos_control_overlay", visible: true

    send_keys :f7
    assert_selector "#pos_control_overlay", visible: true
    assert_selector "#pos-control-title", text: "Line discount"
    send_keys :escape
    assert_no_selector "#pos_control_overlay", visible: true

    click_on "Tax Class"
    assert_selector "#pos_control_overlay", visible: true
    assert_selector "#pos-control-title", text: "Tax Class override"
    send_keys :escape
    assert_no_selector "#pos_control_overlay", visible: true
  end

  test "other picker traps tab inside the overlay" do
    TenderType.create!(
      code: "voucher_tab",
      name: "Store Voucher",
      behavioral_category: "other",
      external_reference_policy: "omitted",
      active: true
    )
    TenderType.create!(
      code: "campus_tab",
      name: "Campus Charge",
      behavioral_category: "other",
      external_reference_policy: "required",
      active: true
    )
    open_register
    add_current_sku
    send_keys :f4
    assert_selector "#pos_other_overlay", visible: true
    assert page.evaluate_script("document.activeElement === document.querySelector('#pos_other_overlay li.is-selected')")
    find("#pos_other_overlay li.is-selected").send_keys :tab
    assert page.evaluate_script("Boolean(document.activeElement && document.activeElement.closest('#pos_other_overlay'))")
    page.send_keys :tab
    assert page.evaluate_script("Boolean(document.activeElement && document.activeElement.closest('#pos_other_overlay'))")
  end

  test "empty basket disables cancel" do
    open_register
    assert_button "Cancel (F9)", disabled: true
    assert_button "Close register"
  end

  test "quantity mode prefills and invalid quantity stays in quantity" do
    open_register
    add_current_sku
    click_on "Quantity (*)"
    assert_text "QUANTITY"
    field = find("#pos-command-field")
    assert_equal "1", field.value
    field.fill_in with: "0"
    field.send_keys :enter
    assert_text "QUANTITY"
    assert_text "quantity must be positive"
    assert_equal "0", find("#pos-command-field").value
  end

  test "insufficient cash stays in tender and escape returns to sale entry" do
    open_register
    add_current_sku
    click_on "Tender (+)"
    assert_text "CASH TENDER"
    field = find("#pos-command-field")
    field.fill_in with: "0.01"
    field.send_keys :enter
    assert_text "CASH TENDER"
    assert_text "less than amount due"
    send_keys :escape
    assert_text "SALE ENTRY"
    assert_text "Scan or identifier"
  end

  test "cancel overlay ignores enter and confirms on f9" do
    open_register
    add_current_sku
    send_keys :f9
    assert_text "Cancel this transaction?"
    send_keys :enter
    assert_text "Cancel this transaction?"
    assert_text "Example Book"
    send_keys :f9
    assert_text "SALE ENTRY"
    assert_no_text "Example Book"
  end

  test "completed receipt enter is a no-op and workspace without a working sale returns to enter" do
    open_register
    add_current_sku
    click_on "Tender (+)"
    field = find("#pos-command-field")
    field.fill_in with: "50.00"
    field.send_keys :enter
    assert_text "Transaction complete", wait: 10
    send_keys :enter
    assert_text "Transaction complete"
    visit pos_register_workspace_path
    assert_text "Open register"
  end

  test "unknown identifier feedback does not move the command field" do
    open_register
    field = find("#pos-command-field")
    before = command_field_top
    field.fill_in with: "0000000000000"
    field.send_keys :enter
    assert_css "#pos_feedback"
    assert_equal before, command_field_top
  end

  test "in-flight mutation ignores tender remove and cancel" do
    open_register
    add_current_sku
    page.execute_script(<<~JS)
      const el = document.getElementById("pos_workspace")
      const controller = window.Stimulus.getControllerForElementAndIdentifier(el, "register-workspace")
      controller.beginFlight()
      controller.enterTender()
      controller.removeSelected()
      controller.openOverlay()
    JS
    assert_button "Tender (+)", disabled: true
    assert_button "Remove (F8)", disabled: true
    assert_button "Cancel (F9)", disabled: true
    assert_text "SALE ENTRY"
    assert_no_text "CASH TENDER"
    assert_no_text "Cancel this transaction?"
    assert_text "Example Book"
  end

  test "active in_flight completion has no recovery controls" do
    open_register
    add_current_sku
    seed_in_flight_completion
    visit pos_register_workspace_path
    assert_text "Completion is still processing"
    assert_no_button "Retry complete"
    assert_no_button "Return to sale"
    assert_button "Cancel (F9)", disabled: true
    assert_selector "input[name='completion_operation_id']", visible: false
    visit pos_register_workspace_path
    assert_text "Completion is still processing"
    assert_no_button "Retry complete"
  end

  test "return to sale from a failed completion clears the tender" do
    open_register
    add_current_sku
    shrink_current_sku(5)
    click_on "Tender (+)"
    field = find("#pos-command-field")
    field.fill_in with: "50.00"
    field.send_keys :enter
    assert_text "Retry complete", wait: 10
    click_on "Return to sale"
    assert_text "SALE ENTRY"
    assert_text "Example Book"
    assert_no_text "CHANGE"
    assert_equal 0, PosTransaction.working.find_by!(register: @register).pos_tenders.count
  end

  test "transport failure on merchandise reloads the workspace" do
    open_register
    add_current_sku
    page.execute_script(<<~JS)
      const el = document.getElementById("pos_workspace")
      const controller = window.Stimulus.getControllerForElementAndIdentifier(el, "register-workspace")
      controller.beginFlight()
      const form = el.querySelector("[data-register-workspace-target='merchandiseForm']")
      form.dispatchEvent(new CustomEvent("turbo:submit-end", { bubbles: true, detail: { success: false } }))
    JS
    assert_text "SALE ENTRY"
    assert_text "Example Book"
  end

  test "transport failure on complete keeps the same operation and offers retry" do
    open_register
    add_current_sku
    shrink_current_sku(5)
    click_on "Tender (+)"
    field = find("#pos-command-field")
    field.fill_in with: "50.00"
    field.send_keys :enter
    assert_text "Retry complete", wait: 10
    operation_id = find("input[name='completion_operation_id']", visible: :hidden).value
    page.execute_script(<<~JS)
      const el = document.getElementById("pos_workspace")
      const controller = window.Stimulus.getControllerForElementAndIdentifier(el, "register-workspace")
      controller.beginFlight()
      const form = el.querySelector("[data-register-workspace-target='completeForm']")
      form.dispatchEvent(new CustomEvent("turbo:submit-end", { bubbles: true, detail: { success: false } }))
    JS
    assert_text "Connection lost"
    assert_text "Retry complete"
    assert_equal operation_id, find("input[name='completion_operation_id']", visible: :hidden).value
  end

  test "retry complete after inventory failure does not re-tender" do
    open_register
    add_current_sku
    shrink_current_sku(5)
    click_on "Tender (+)"
    field = find("#pos-command-field")
    field.fill_in with: "50.00"
    field.send_keys :enter
    assert_text "Retry complete", wait: 10
    transaction = PosTransaction.working.find_by!(register: @register)
    assert_equal 1, transaction.pos_tenders.count

    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 5)
    click_on "Retry complete"
    assert_text "Transaction complete", wait: 10
    completed = PosTransaction.completed.find_by!(register: @register)
    assert_equal 1, completed.pos_tenders.count
    assert_equal 1, OutboxMessage.where(event_type: "pos.transaction_completed").count
  end

  test "cashier can complete a mixed cash basket of standard used and non-inventory" do
    _used_variant, unit = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax, name: "Used Book")
    service = pos_sellable_variant(
      actor: @actor,
      tax_class: @tax,
      inventory_mode: "non_inventory",
      name: "Store Service"
    )
    condition_code = unit.product_variant.merchandise_condition.code

    open_register
    add_current_sku
    field = find("#pos-command-field")
    field.fill_in with: @variant.sku
    field.send_keys :enter
    assert_selector "tr.is-selected[data-quantity='2']"

    field.fill_in with: unit.unit_identifier
    field.send_keys :enter
    assert_selector "tr.is-selected[data-unit-line='true']"
    assert_text unit.unit_identifier
    assert_button "Quantity (*)", disabled: true
    send_keys "*"
    assert_text "SALE ENTRY"
    assert_no_text "QUANTITY"

    field = find("#pos-command-field")
    field.fill_in with: service.sku
    field.send_keys :enter
    assert_text "Store Service"

    click_on "Tender (+)"
    field = find("#pos-command-field")
    field.fill_in with: "100.00"
    field.send_keys :enter
    send_keys :enter

    assert_text "Transaction complete", wait: 10
    assert_text unit.unit_identifier
    assert_text condition_code
    assert_text "Used Book"
    assert_text "Store Service"
    assert_equal 1, PosTransaction.completed.where(register: @register).count
  end

  test "cashier can open completed history and reprint without changing the sale" do
    open_register
    add_current_sku
    click_on "Tender (+)"
    field = find("#pos-command-field")
    field.fill_in with: "50.00"
    field.send_keys :enter
    send_keys :enter
    assert_text "Transaction complete", wait: 10
    completed = PosTransaction.completed.find_by!(register: @register)
    counts = {
      transactions: PosTransaction.count,
      tenders: PosTender.count,
      ledger: InventoryLedgerEntry.count,
      outbox: OutboxMessage.count,
      receipt: completed.receipt_sequence
    }

    click_on "Transactions"
    assert_text completed.transaction_reference
    click_on completed.transaction_reference
    assert_selector ".pos-receipt__reprint", text: "REPRINT", visible: :all
    assert_text "Example Book"
    assert_equal counts[:transactions], PosTransaction.count
    assert_equal counts[:tenders], PosTender.count
    assert_equal counts[:ledger], InventoryLedgerEntry.count
    assert_equal counts[:outbox], OutboxMessage.count
    assert_equal counts[:receipt], completed.reload.receipt_sequence
  end

  test "f1 through f4 select tenders and f10 preserves the working basket" do
    open_register
    add_current_sku
    send_keys :f4
    assert_text "No Other tender types are configured."
    assert_text "SALE ENTRY"

    send_keys :f1
    assert_text "CASH TENDER"
    field = find("#pos-command-field")
    refute_equal "", field.value

    send_keys :f10
    assert_text "Transactions"
    click_on "Register"
    assert_text "Example Book"
    assert_text "SALE ENTRY"

    click_on "Tender (+)"
    send_keys :f2
    field = find("#pos-command-field")
    field.fill_in with: "10.00"
    field.send_keys :enter
    assert_selector ".pos-totals", text: "External Card"
    send_keys :f10
    assert_text "Transactions"
    click_on "Register"
    assert_selector ".pos-totals", text: "External Card"
    assert_text "Example Book"
  end

  test "f4 other none one and many and f10 is blocked by an overlay" do
    TenderType.create!(
      code: "voucher",
      name: "Store Voucher",
      behavioral_category: "other",
      external_reference_policy: "omitted",
      active: true
    )
    open_register
    add_current_sku
    send_keys :f4
    assert_text "TENDER"
    assert_selector "[data-register-workspace-target='fieldLabel']", text: /Store Voucher/

    TenderType.create!(
      code: "campus_charge",
      name: "Campus Charge",
      behavioral_category: "other",
      external_reference_policy: "required",
      active: true
    )
    visit pos_register_workspace_path
    assert_text "SALE ENTRY"
    send_keys :escape
    send_keys :f4
    assert_selector "#pos_other_overlay", visible: true
    assert_selector "#pos_other_overlay li.is-selected", text: "Campus Charge"
    assert page.evaluate_script("document.activeElement === document.querySelector('#pos_other_overlay li.is-selected')")
    assert_text "SALE ENTRY"
    send_keys :enter
    assert_no_selector "#pos_other_overlay", visible: true
    assert_text "TENDER"
    assert_selector "[data-register-workspace-target='fieldLabel']", text: /Campus Charge/
    assert_field "Reference (required)"
    field = find("#pos-command-field")
    field.send_keys :enter
    assert_equal "pos-reference-field", page.evaluate_script("document.activeElement && document.activeElement.id")

    send_keys :escape
    send_keys :f6
    assert_selector "#pos_control_overlay", visible: true
    send_keys :f10
    assert_text "Finish or cancel the current dialog before opening Transactions."
    assert_selector "#pos_control_overlay", visible: true
    assert_no_selector "h1", text: "Transactions"
  end

  test "slash search always lists results and enter adds the highlighted item" do
    open_register
    field = find("#pos-command-field")
    field.send_keys "/"
    assert_selector "#pos_search_overlay", visible: true
    fill_in "SKU", with: @variant.sku
    find("[data-register-workspace-target='searchSkuField']").send_keys :enter
    assert_selector "#pos_search_overlay li", minimum: 1
    find("[data-register-workspace-target='searchList'] li.is-selected").send_keys :enter
    assert_text "Example Book"
    assert_no_selector "#pos_search_overlay", visible: true
  end

  test "open-price prompt escape does not add a line" do
    open_price = pos_sellable_variant(actor: @actor, tax_class: @tax, pricing_method: "open_price", name: "Open Book")
    open_quantity_stock(store: @store, variant: open_price, actor: @actor, quantity: 3)
    open_register
    field = find("#pos-command-field")
    field.fill_in with: open_price.sku
    field.send_keys :enter
    assert_selector "#pos_open_price_overlay", visible: true
    send_keys :escape
    assert_no_selector "#pos_open_price_overlay", visible: true
    assert_no_text "Open Book"
    assert_equal 0, PosTransaction.working.find_by!(register: @register).pos_transaction_lines.count
  end

  test "shared lookup code opens the product picker and enter adds the highlighted product" do
    other = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Beta Shared")
    open_quantity_stock(store: @store, variant: other, actor: @actor, quantity: 3)
    @variant.product.update!(lookup_code: "SHARED")
    other.product.update!(lookup_code: "SHARED")

    open_register
    field = find("#pos-command-field")
    field.fill_in with: "shared"
    field.send_keys :enter

    assert_selector "#pos_product_overlay", visible: true
    assert_selector "#pos_product_overlay li", count: 2
    assert page.evaluate_script("document.activeElement === document.querySelector('#pos_product_overlay li.is-selected')")
    assert_equal 0, PosTransaction.working.find_by!(register: @register).pos_transaction_lines.count

    send_keys :escape
    assert_no_selector "#pos_product_overlay", visible: true
    assert_no_text "Beta Shared"
    assert_equal 0, PosTransaction.working.find_by!(register: @register).pos_transaction_lines.count

    field = find("#pos-command-field")
    field.fill_in with: "shared"
    field.send_keys :enter
    assert_selector "#pos_product_overlay", visible: true
    send_keys :arrow_down
    send_keys :enter

    assert_no_selector "#pos_product_overlay", visible: true
    assert_text "Example Book"
    assert_equal 1, PosTransaction.working.find_by!(register: @register).pos_transaction_lines.count
  end

  test "minus opens linked and unlinked chooser from empty sale entry" do
    open_register
    click_on "Return (-)"
    assert_selector "#pos_return_chooser", visible: true
    assert_selector "#pos_return_chooser li.is-selected", text: "Linked return"
    assert page.evaluate_script("document.activeElement === document.querySelector('#pos_return_chooser li.is-selected')")
    send_keys :arrow_down
    send_keys :enter
    assert_selector "#pos_unlinked_overlay", visible: true
    send_keys :escape
    assert_no_selector "#pos_unlinked_overlay", visible: true
    click_on "Return (-)"
    send_keys :enter
    assert_selector "#pos_linked_overlay", visible: true
    assert_field "Receipt, merchandise, or unit"
    send_keys :escape
    assert_no_selector "#pos_linked_overlay", visible: true
    send_keys "-"
    assert_selector "#pos_return_chooser", visible: true
  end

  test "cashier attaches a customer from operational search overlay" do
    Customer.create!(display_name: "Overlay Customer", email: "overlay.customer@example.com")
    open_register
    click_on "Attach customer"
    assert_selector "#pos_customer_overlay", visible: true
    field = find("[data-register-workspace-target='customerQueryField']")
    field.fill_in with: "Overlay Customer"
    field.send_keys :enter
    assert_selector "#pos_customer_overlay li", text: "Overlay Customer", wait: 10
    field.send_keys :enter
    assert_no_selector "#pos_customer_overlay", visible: true, wait: 10
    assert_text "Customer · Overlay Customer"
  end

  private

  test "gift-card shaped scan does not add merchandise" do
    GiftCards::Programs.seed!
    program = GiftCardProgram.find_by!(code: "generated")
    number = GiftCards::Number.generate(program)

    open_register
    field = find("#pos-command-field")
    field.fill_in with: number
    field.send_keys :enter
    assert_text(/gift card not on file/i, wait: 10)
    assert_no_selector "tbody tr"
  end

  def sign_in_admin
    visit new_session_path
    fill_in "session_username", with: "admin"
    fill_in "session_password", with: "correct-horse-battery"
    find_field("session_password").send_keys :enter
    assert_text "Signed in successfully"
  end

  def open_register
    sign_in_admin
    visit pos_register_enter_path(register_id: @register.id)
    fill_in "Opening float", with: "0.00"
    click_on "Open register"
    assert_text "SALE ENTRY", wait: 10
  end

  def add_current_sku
    field = find("#pos-command-field")
    field.fill_in with: @variant.sku
    field.send_keys :enter
    assert_selector "tbody tr.is-selected", text: "Example Book", wait: 10
  end

  def command_field_top
    page.evaluate_script("document.getElementById('pos-command-field').getBoundingClientRect().top")
  end

  def seed_in_flight_completion
    transaction = PosTransaction.working.find_by!(register: @register)
    Pos::TenderCash.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: 2500
    )
    transaction.reload
    operation_id = SecureRandom.uuid_v7
    payload = Pos::CompleteTransaction.command_payload(
      transaction: transaction,
      operation_id: operation_id,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents
    )
    Pos::OperationLease.begin!(
      register_id: transaction.register_id,
      operation_id: operation_id,
      command_payload: payload,
      store_id: transaction.store_id,
      pos_transaction_id: transaction.id
    )
    operation_id
  end

  def shrink_current_sku(quantity)
    Inventory::AdjustmentReasons.seed!
    Inventory::PostAdjustment.call(
      store: @store,
      product_variant: @variant,
      adjustment_reason: AdjustmentReason.find_by!(code: "shrinkage"),
      quantity_delta: -quantity,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    )
  end
end
