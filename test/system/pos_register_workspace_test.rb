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

    start_cash_tender_via_plus
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
    start_cash_tender_via_plus
    assert_text "CASH TENDER"
    assert_no_selector "[data-register-workspace-target='referenceWrap']", visible: true
    send_keys :f2
    assert_selector "[data-register-workspace-target='fieldLabel']", text: /External Card/
    assert_selector "[data-register-workspace-target='referenceWrap']", visible: true
    assert_field "Reference (optional)"
    field = find("#pos-command-field")
    field.fill_in with: "10.00"
    field.send_keys :enter
    assert_selector "#pos_tenders", text: "External Card"
    assert_no_selector "#pos_totals", text: "External Card"
    assert_text "Balance due"
    assert_equal "pos-command-field", page.evaluate_script("document.activeElement && document.activeElement.id")
    click_on "Return to sale"
    assert_text "SALE ENTRY"
    assert_no_selector "#pos_tenders", text: "External Card"

    start_cash_tender_via_plus
    send_keys :f2
    assert_selector "[data-register-workspace-target='fieldLabel']", text: /External Card/
    field = find("#pos-command-field")
    field.fill_in with: "10.00"
    field.send_keys :enter
    assert_selector "#pos_tenders", text: "External Card"
    assert_no_selector "#pos_totals", text: "External Card"
    assert_text "Balance due"
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
    fill_in "New selling price", with: "15.00"
    select "Damaged", from: "Reason"
    find("#pos-control-price").send_keys :enter

    assert_selector "#pos_approval_overlay", visible: true
    assert_selector "#pos_control_overlay[inert]", visible: :all
    assert_equal "pos-approver-username", page.evaluate_script("document.activeElement && document.activeElement.id")
    line = PosTransaction.working.find_by!(register: @register).pos_transaction_lines.first
    assert_equal line.reference_unit_price_cents, line.selling_unit_price_cents

    username = find("#pos-approver-username")
    username.fill_in with: "mgr_scan"
    username.send_keys :enter

    assert_selector "#pos_approval_overlay", visible: true
    assert_equal "pos-approver-password", page.evaluate_script("document.activeElement && document.activeElement.id")
    line.reload
    assert_equal line.reference_unit_price_cents, line.selling_unit_price_cents
  end

  test "rejected approver credentials stay in authorization overlay" do
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
    fill_in "New selling price", with: "15.00"
    select "Damaged", from: "Reason"
    click_on "Apply"
    assert_selector "#pos_approval_overlay", visible: true
    fill_in "Approver username", with: "mgr_retry"
    find("#pos-approver-password").fill_in with: "typoooo"
    find("#pos-approver-password").send_keys :enter

    assert_selector "#pos_approval_overlay", visible: true
    assert_selector "#pos-approval-feedback", text: /Manager credentials were not accepted/
    assert_selector "#pos_control_overlay", visible: true
    assert_field "New selling price", with: "15.00"
    assert_field "Approver username", with: "mgr_retry"
    assert_equal "", find("#pos-approver-password").value
    assert_equal "pos-approver-password", page.evaluate_script("document.activeElement && document.activeElement.id")
    line = PosTransaction.working.find_by!(register: @register).pos_transaction_lines.first
    assert_equal line.reference_unit_price_cents, line.selling_unit_price_cents

    find("#pos-approver-password").fill_in with: "correct-horse-battery"
    find("#pos-approver-password").send_keys :enter
    assert_no_selector "#pos_approval_overlay", visible: true
    assert_no_selector "#pos_control_overlay", visible: true
    assert_equal 1500, line.reload.selling_unit_price_cents
  end

  test "incomplete price overlay does not open authorization" do
    pos_transacting_user(store: @store, assigned_by: @actor, username: "clerk_ready5c")
    pos_store_manager(store: @store, assigned_by: @actor, username: "mgr_ready5c")
    visit new_session_path
    fill_in "session_username", with: "clerk_ready5c"
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
    fill_in "New selling price", with: "15.00"
    click_on "Apply"
    assert_no_selector "#pos_approval_overlay", visible: true
    assert_selector "#pos_control_overlay", visible: true
    assert_selector "#pos-control-feedback", text: /Choose a reason/
    assert_equal "pos-control-reason", page.evaluate_script("document.activeElement && document.activeElement.id")
  end

  test "enter from a direct price field applies the override" do
    open_register
    add_current_sku

    click_on "Price (F6)"
    assert_selector "#pos_control_overlay", visible: true
    assert_selector "#pos-control-title", text: "Change Selling Price"
    fill_in "New selling price", with: "15.00"
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
    assert_selector "#pos-control-title", text: "Change Selling Price"
    send_keys :escape
    assert_no_selector "#pos_control_overlay", visible: true

    send_keys :f7
    assert_selector "#pos_control_overlay", visible: true
    assert_selector "#pos-control-title", text: "Apply Line Discount"
    send_keys :escape
    assert_no_selector "#pos_control_overlay", visible: true

    click_on "Tax Class"
    assert_selector "#pos_control_overlay", visible: true
    assert_selector "#pos-control-title", text: "Change Tax Class"
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
    assert_button "Close Session"
  end

  test "command field stays clickable above the basket" do
    open_register
    field = find("#pos-command-field")
    hit = page.evaluate_script(<<~JS.squish)
      (function() {
        var el = document.getElementById("pos-command-field");
        var box = el.getBoundingClientRect();
        var top = document.elementFromPoint(box.left + box.width / 2, box.top + box.height / 2);
        return Boolean(top && (top === el || el.contains(top)));
      })()
    JS
    assert hit, "command field must not be covered by shell chrome"
    field.click
    field.send_keys @variant.sku, :enter
    assert_selector "tbody tr.is-selected", text: "Example Book", wait: 10
    command_top = command_field_top
    basket_top = page.evaluate_script("document.getElementById('pos_basket').getBoundingClientRect().top")
    assert command_top < basket_top, "command field must sit above the basket"
  end

  test "typed identifiers reach the command field after clicking the header" do
    open_register
    find(".pos-header__cashier").click
    send_keys @variant.sku, :enter
    assert_selector "tbody tr.is-selected", text: "Example Book", wait: 10
  end

  test "basket scrolls to keep the selected line in view" do
    variants = 6.times.map do |index|
      variant = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Scroll Book #{index}")
      open_quantity_stock(store: @store, variant: variant, actor: @actor, quantity: 2)
      variant
    end

    open_register
    page.execute_script("var s=document.createElement('style'); s.id='pos-basket-scroll-probe'; s.textContent='#pos_basket{max-height:90px!important}'; document.head.appendChild(s);")
    variants.each do |variant|
      field = find("#pos-command-field")
      field.fill_in with: variant.sku
      field.send_keys :enter
      assert_selector "tbody tr.is-selected", text: "Scroll Book", wait: 10
    end
    assert_selector "tbody tr.is-selected", text: "Scroll Book 5"
    assert selected_row_fully_in_basket?, "newly selected line must stay in the basket viewport"

    page.execute_script("document.getElementById('pos_basket').scrollTop = 0")
    refute selected_row_fully_in_basket?, "precondition: selected line starts out of view"

    send_keys :arrow_down
    assert_selector "tbody tr.is-selected", text: "Scroll Book 5"
    assert selected_row_fully_in_basket?, "selection change must scroll the highlighted line into view"

    5.times { send_keys :arrow_up }
    assert_selector "tbody tr.is-selected", text: "Scroll Book 0"
    assert selected_row_fully_in_basket?, "arrow selection must scroll the highlighted line into view"
  end

  test "quantity mode prefills and invalid quantity stays in quantity" do
    open_register
    add_current_sku
    click_on "Quantity (*)"
    assert_text "QUANTITY"
    send_keys :f10
    assert_selector "#register-menu", visible: true
    send_keys :escape
    assert_selector "#register-menu", visible: :hidden
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
    start_cash_tender_via_plus
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
    assert_text "1 item for sale will be discarded"
    assert_text "No receipt, inventory movement, or stored-value issuance will be completed"
    send_keys :enter
    assert_text "Cancel this transaction?"
    assert_text "Example Book"
    send_keys :f9
    assert_text "SALE ENTRY"
    assert_no_text "Example Book"
  end

  test "authorization escape restores control parent without credentials" do
    pos_transacting_user(store: @store, assigned_by: @actor, username: "clerk_esc5c")
    pos_store_manager(store: @store, assigned_by: @actor, username: "mgr_esc5c")
    visit new_session_path
    fill_in "session_username", with: "clerk_esc5c"
    fill_in "session_password", with: "correct-horse-battery"
    find_field("session_password").send_keys :enter
    assert_text "Signed in successfully"
    visit pos_register_enter_path(register_id: @register.id)
    fill_in "Opening float", with: "0.00"
    click_on "Open register"
    assert_text "SALE ENTRY"
    add_current_sku

    click_on "Price (F6)"
    fill_in "New selling price", with: "15.00"
    select "Damaged", from: "Reason"
    click_on "Apply"
    assert_selector "#pos_approval_overlay", visible: true
    fill_in "Approver username", with: "mgr_esc5c"
    find("#pos-approver-password").fill_in with: "temp-secret"
    send_keys :escape
    assert_no_selector "#pos_approval_overlay", visible: true
    assert_selector "#pos_control_overlay", visible: true
    assert_field "New selling price", with: "15.00"
    assert_equal "", find("#pos-approver-password", visible: :all).value
    assert_equal "", find("#pos-approver-username", visible: :all).value
  end

  test "closing control parent clears prior authorization invocation before unlinked" do
    pos_transacting_user(store: @store, assigned_by: @actor, username: "clerk_iso5c")
    pos_store_manager(store: @store, assigned_by: @actor, username: "mgr_iso5c")
    visit new_session_path
    fill_in "session_username", with: "clerk_iso5c"
    fill_in "session_password", with: "correct-horse-battery"
    find_field("session_password").send_keys :enter
    assert_text "Signed in successfully"
    visit pos_register_enter_path(register_id: @register.id)
    fill_in "Opening float", with: "0.00"
    click_on "Open register"
    assert_text "SALE ENTRY"
    add_current_sku

    click_on "Price (F6)"
    fill_in "New selling price", with: "15.00"
    select "Damaged", from: "Reason"
    click_on "Apply"
    assert_selector "#pos_approval_overlay", visible: true
    assert_text "Price change"
    click_on "Back to Price Change"
    click_on "Keep Current Price"

    click_on "Return (-)"
    send_keys :arrow_down
    send_keys :enter
    assert_selector "#pos_unlinked_overlay", visible: true
    identifier = find("#pos-unlinked-identifier")
    identifier.fill_in with: @variant.sku
    identifier.send_keys :enter
    assert_text "Example Book", wait: 5
    fill_in "Return unit price", with: "18.00"
    select "Defective", from: "Return reason"
    click_on "Add Unlinked Return"
    assert_selector "#pos_approval_overlay", visible: true
    assert_text "Unlinked return"
    assert_no_text "Price change"
    assert_equal "", find("#pos-approver-username").value
    assert_equal "", find("#pos-approver-password").value
  end

  test "completed receipt enter is a no-op and workspace without a working sale returns to enter" do
    open_register
    add_current_sku
    start_cash_tender_via_plus
    field = find("#pos-command-field")
    field.fill_in with: "50.00"
    field.send_keys :enter
    assert_text "Transaction complete", wait: 10
    send_keys :enter
    assert_text "Transaction complete"
    visit pos_register_workspace_path
    assert_text "Resume Register"
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
    start_cash_tender_via_plus
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
    start_cash_tender_via_plus
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
    start_cash_tender_via_plus
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

    start_cash_tender_via_plus
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
    start_cash_tender_via_plus
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
    assert_selector "#register-menu", visible: true
    send_keys :escape
    assert_selector "#register-menu", visible: :hidden
    assert_text "CASH TENDER"
    assert page.evaluate_script("document.activeElement === document.getElementById('pos-command-field')")

    choose_register_menu "Transactions & Receipts"
    assert_selector "h1", text: /Transactions/
    click_on "Return to Register"
    assert_text "Example Book"
    assert_text "SALE ENTRY"

    start_cash_tender_via_plus
    send_keys :f2
    field = find("#pos-command-field")
    field.fill_in with: "10.00"
    field.send_keys :enter
    assert_selector "#pos_tenders", text: "External Card"
    assert_no_selector "#pos_totals", text: "External Card"
    choose_register_menu "Transactions & Receipts"
    assert_selector "h1", text: /Transactions/
    click_on "Return to Register"
    assert_selector "#pos_tenders", text: "External Card"
    assert_no_selector "#pos_totals", text: "External Card"
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
    assert_text "Finish or cancel the current dialog before opening the Register Menu."
    assert_selector "#pos_control_overlay", visible: true
    assert_selector "#register-menu", visible: :hidden
    assert_no_selector "h1", text: "Transactions"

    click_launcher_menu
    assert_text "Finish or cancel the current dialog before opening the Register Menu."
    assert_selector "#pos_control_overlay", visible: true
    assert_selector "#register-menu", visible: :hidden
  end

  test "nonempty basket hides close session in the register menu" do
    open_register
    assert_button "Close Session"
    open_register_menu
    assert_button "Close Session"
    send_keys :escape
    add_current_sku
    assert_no_button "Close Session"
    open_register_menu
    assert_no_button "Close Session"
  end

  test "slash search always lists results and enter adds the highlighted item" do
    open_register
    field = find("#pos-command-field")
    field.send_keys "/"
    assert_selector "#pos_search_overlay", visible: true
    assert page.evaluate_script("document.activeElement === document.querySelector('[data-register-workspace-target=searchSkuField]')")
    assert page.evaluate_script("document.querySelector('[data-register-workspace-target=background]').inert === true")
    fill_in "SKU", with: @variant.sku
    find("[data-register-workspace-target='searchSkuField']").send_keys :enter
    assert_selector "#pos_search_overlay li", minimum: 1
    find("[data-register-workspace-target='searchList'] li.is-selected").send_keys :enter
    assert_text "Example Book"
    assert_no_selector "#pos_search_overlay", visible: true
  end

  test "slash search can be completed with pointer confirmation" do
    open_register
    find("#pos-command-field").send_keys "/"
    fill_in "SKU", with: @variant.sku
    find("[data-register-workspace-target='searchSkuField']").send_keys :enter
    assert_selector "#pos_search_overlay li.is-selected", wait: 10
    find("#pos_search_overlay li.is-selected").click
    click_on "Choose Product"
    assert_text "Example Book"
    assert_no_selector "#pos_search_overlay", visible: true
  end

  test "open-price add focuses an empty price field" do
    open_price = pos_sellable_variant(actor: @actor, tax_class: @tax, pricing_method: "open_price", name: "Open Book")
    open_quantity_stock(store: @store, variant: open_price, actor: @actor, quantity: 3)
    open_register
    field = find("#pos-command-field")
    field.fill_in with: open_price.sku
    field.send_keys :enter
    assert_selector "#pos_open_price_overlay", visible: true
    assert_equal "Open price", find("#pos-open-price-title").text
    price = find("[data-register-workspace-target='openPriceField']")
    assert_equal "", price.value
    assert page.evaluate_script("document.activeElement === document.querySelector('[data-register-workspace-target=openPriceField]')")
  end

  test "open-price edit selects a zero price value" do
    open_price = pos_sellable_variant(actor: @actor, tax_class: @tax, pricing_method: "open_price", name: "Zero Book")
    open_quantity_stock(store: @store, variant: open_price, actor: @actor, quantity: 3)
    open_register
    # Anchor the basket with a paid line so a $0.00 open-price line does not auto-complete.
    add_current_sku
    field = find("#pos-command-field")
    field.fill_in with: open_price.sku
    field.send_keys :enter
    assert_selector "#pos_open_price_overlay", visible: true
    price = find("[data-register-workspace-target='openPriceField']")
    price.fill_in with: "0.00"
    click_on "Apply"
    assert_selector "tbody tr.is-selected", text: "Zero Book", wait: 10
    send_keys :f6
    assert_selector "#pos_open_price_overlay", visible: true
    assert_equal "0.00", find("[data-register-workspace-target='openPriceField']").value
    assert_equal "Edit open price", find("#pos-open-price-title").text
    selected = page.evaluate_script(<<~JS.squish)
      (function() {
        var field = document.querySelector("[data-register-workspace-target='openPriceField']");
        return field && document.activeElement === field &&
          field.selectionStart === 0 && field.selectionEnd === field.value.length;
      })()
    JS
    assert selected, "zero open price must be fully selected for overwrite"
  end

  test "product then variant Escape restores the product stage" do
    other = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Beta Shared")
    open_quantity_stock(store: @store, variant: other, actor: @actor, quantity: 3)
    ProductVariants::Create.call(
      product: @variant.product,
      attributes: {
        variant_type: "standard",
        status: "active",
        merchandise_class_id: @variant.merchandise_class_id,
        regular_price_cents: 1500
      },
      actor: @actor
    )
    open_quantity_stock(store: @store, variant: @variant.product.product_variants.order(:created_at).last, actor: @actor, quantity: 3)
    @variant.product.update!(lookup_code: "NESTED")
    other.product.update!(lookup_code: "NESTED")

    open_register
    field = find("#pos-command-field")
    field.fill_in with: "nested"
    field.send_keys :enter
    assert_selector "#pos_product_overlay", visible: true
    assert page.evaluate_script("document.querySelector('[data-register-workspace-target=background]').inert === true")
    find("#pos_product_overlay li", text: /Example Book/).click
    click_on "Choose Product"
    assert_selector "#pos_variant_overlay", visible: true, wait: 10
    assert page.evaluate_script("document.querySelector('#pos_product_overlay').inert === true")
    assert page.evaluate_script("document.querySelector('[data-register-shell-target=header]').inert === true")
    send_keys :escape
    assert_no_selector "#pos_variant_overlay", visible: true
    assert_selector "#pos_product_overlay", visible: true
    assert page.evaluate_script("document.querySelector('#pos_product_overlay').inert === false")
    assert page.evaluate_script("document.activeElement === document.querySelector('#pos_product_overlay li.is-selected')")
    click_on "Choose Product"
    assert_selector "#pos_variant_overlay", visible: true, wait: 10
    click_on "Back to Products"
    assert_no_selector "#pos_variant_overlay", visible: true
    assert_selector "#pos_product_overlay", visible: true
    send_keys :escape
    assert_no_selector "#pos_product_overlay", visible: true
    assert page.evaluate_script("document.activeElement === document.getElementById('pos-command-field')")
  end

  test "escape during search leaves a late response ignored" do
    open_register
    find("#pos-command-field").send_keys "/"
    assert_selector "#pos_search_overlay", visible: true
    page.evaluate_script(<<~JS.squish)
      (function() {
        window.__ssSearchFetch = window.fetch.bind(window);
        window.fetch = function(input, init) {
          var url = typeof input === "string" ? input : (input && input.url) || "";
          if (String(url).indexOf("merchandise_search") !== -1) {
            return new Promise(function(resolve) {
              window.__ssDelayedSearch = { resolve: resolve, init: init, input: input };
            });
          }
          return window.__ssSearchFetch(input, init);
        };
      })()
    JS
    fill_in "SKU", with: @variant.sku
    find("[data-register-workspace-target='searchSkuField']").send_keys :enter
    assert_text "Searching…", wait: 5
    send_keys :escape
    assert_no_selector "#pos_search_overlay", visible: true
    assert page.evaluate_script("document.activeElement === document.getElementById('pos-command-field')")
    page.execute_script(<<~JS.squish)
      (function() {
        if (!window.__ssDelayedSearch) return;
        window.__ssSearchFetch(window.__ssDelayedSearch.input, window.__ssDelayedSearch.init).then(function(response) {
          window.__ssDelayedSearch.resolve(response);
        });
        window.fetch = window.__ssSearchFetch;
      })()
    JS
    sleep 0.5
    assert_no_selector "#pos_search_overlay", visible: true
    assert page.evaluate_script("document.activeElement === document.getElementById('pos-command-field')")
    assert_no_selector "#pos_search_overlay li"
  ensure
    page.execute_script("if (window.__ssSearchFetch) { window.fetch = window.__ssSearchFetch; }")
  end

  test "late search response after close does not populate a reopened overlay" do
    open_register
    find("#pos-command-field").send_keys "/"
    assert_selector "#pos_search_overlay", visible: true
    page.evaluate_script(<<~JS.squish)
      (function() {
        window.__ssSearchFetch = window.fetch.bind(window);
        window.fetch = function(input, init) {
          var url = typeof input === "string" ? input : (input && input.url) || "";
          if (String(url).indexOf("merchandise_search") !== -1) {
            return new Promise(function(resolve) {
              window.__ssDelayedSearch = { resolve: resolve, init: init, input: input };
            });
          }
          return window.__ssSearchFetch(input, init);
        };
      })()
    JS
    fill_in "SKU", with: @variant.sku
    find("[data-register-workspace-target='searchSkuField']").send_keys :enter
    assert_text "Searching…", wait: 5
    send_keys :escape
    assert_no_selector "#pos_search_overlay", visible: true
    find("#pos-command-field").send_keys "/"
    assert_selector "#pos_search_overlay", visible: true
    assert_no_selector "#pos_search_overlay li"
    page.execute_script(<<~JS.squish)
      (function() {
        if (!window.__ssDelayedSearch) return;
        window.__ssSearchFetch(window.__ssDelayedSearch.input, window.__ssDelayedSearch.init).then(function(response) {
          window.__ssDelayedSearch.resolve(response);
        });
        window.fetch = window.__ssSearchFetch;
      })()
    JS
    sleep 0.5
    assert_selector "#pos_search_overlay", visible: true
    assert_no_selector "#pos_search_overlay li"
    assert page.evaluate_script("document.activeElement === document.querySelector('[data-register-workspace-target=searchSkuField]')")
  ensure
    page.execute_script("if (window.__ssSearchFetch) { window.fetch = window.__ssSearchFetch; }")
  end

  test "editing merchandise search query then enter searches again" do
    other = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Other Search Book")
    open_quantity_stock(store: @store, variant: other, actor: @actor, quantity: 3)
    open_register
    find("#pos-command-field").send_keys "/"
    fill_in "SKU", with: @variant.sku
    find("[data-register-workspace-target='searchSkuField']").send_keys :enter
    assert_selector "#pos_search_overlay li.is-selected", text: /Example Book/, wait: 10
    sku = find("[data-register-workspace-target='searchSkuField']")
    sku.click
    sku.fill_in with: other.sku
    assert_no_selector "#pos_search_overlay li"
    sku.send_keys :enter
    assert_selector "#pos_search_overlay li.is-selected", text: /Other Search Book/, wait: 10
    assert_no_selector "#pos_search_overlay li.is-selected", text: /Example Book/
  end

  test "editing customer search query then enter searches again" do
    Customer.create!(display_name: "Alpha Customer", email: "alpha@example.com")
    Customer.create!(display_name: "Beta Customer", email: "beta@example.com")
    open_register
    click_on "Attach customer"
    field = find("[data-register-workspace-target='customerQueryField']")
    field.fill_in with: "Alpha"
    field.send_keys :enter
    assert_selector "#pos_customer_overlay li.is-selected", text: "Alpha Customer", wait: 10
    field.click
    field.fill_in with: "Beta"
    assert_no_selector "#pos_customer_overlay li"
    field.send_keys :enter
    assert_selector "#pos_customer_overlay li.is-selected", text: "Beta Customer", wait: 10
    assert_no_selector "#pos_customer_overlay li.is-selected", text: "Alpha Customer"
  end

  test "editing pickup search query then enter searches again" do
    alpha = Customer.create!(display_name: "Alpha Pickup", phone: "555-0101")
    beta = Customer.create!(display_name: "Beta Pickup", phone: "555-0102")
    alpha_request = Customers::CreateRequest.call(
      store: @store,
      customer: alpha,
      product_variant: @variant,
      actor: @actor
    )
    Customers::ConfirmLocation.call(customer_request: alpha_request, actor: @actor)
    beta_variant = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Beta Pickup Book")
    open_quantity_stock(store: @store, variant: beta_variant, actor: @actor, quantity: 1)
    beta_request = Customers::CreateRequest.call(
      store: @store,
      customer: beta,
      product_variant: beta_variant,
      actor: @actor
    )
    Customers::ConfirmLocation.call(customer_request: beta_request, actor: @actor)
    open_register
    click_on "Pickup"
    field = find("[data-register-workspace-target='pickupQueryField']")
    field.fill_in with: "Alpha"
    field.send_keys :enter
    assert_selector "#pos_pickup_overlay li.is-selected", text: /Alpha Pickup/, wait: 10
    field.click
    field.fill_in with: "Beta"
    assert_no_selector "#pos_pickup_overlay li"
    field.send_keys :enter
    assert_selector "#pos_pickup_overlay li.is-selected", text: /Beta Pickup/, wait: 10
    assert_no_selector "#pos_pickup_overlay li.is-selected", text: /Alpha Pickup/
  end

  test "search arrow keys skip disabled merchandise results" do
    retired = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Mid Disabled Book")
    retired.update_columns(status: "discontinued")
    other = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Zed Enabled Book")
    open_quantity_stock(store: @store, variant: other, actor: @actor, quantity: 2)
    open_register
    find("#pos-command-field").send_keys "/"
    fill_in "Product name", with: "Book"
    find("[data-register-workspace-target='searchNameField']").send_keys :enter
    assert_selector "#pos_search_overlay li.is-selected:not(.is-disabled)", wait: 10
    assert_selector "#pos_search_overlay li.is-disabled", text: /Mid Disabled Book/, wait: 10
    first_label = find("#pos_search_overlay li.is-selected").text
    send_keys :arrow_down
    second = find("#pos_search_overlay li.is-selected")
    refute second[:class].include?("is-disabled")
    refute_match(/Mid Disabled Book/, second.text)
    refute_equal first_label, second.text
    send_keys :arrow_up
    assert_selector "#pos_search_overlay li.is-selected", text: first_label
    refute find("#pos_search_overlay li.is-selected")[:class].include?("is-disabled")
  end

  test "pickup lookup can be completed with pointer confirmation" do
    customer = Customer.create!(display_name: "Alex Pickup", phone: "555-0100")
    request = Customers::CreateRequest.call(
      store: @store,
      customer: customer,
      product_variant: @variant,
      actor: @actor
    )
    Customers::ConfirmLocation.call(customer_request: request, actor: @actor)
    open_register
    click_on "Pickup"
    assert_selector "#pos_pickup_overlay", visible: true
    field = find("[data-register-workspace-target='pickupQueryField']")
    field.fill_in with: "Alex"
    field.send_keys :enter
    assert_selector "#pos_pickup_overlay li.is-selected", wait: 10
    find("#pos_pickup_overlay li.is-selected").click
    click_on "Add Pickup Items"
    assert_no_selector "#pos_pickup_overlay", visible: true, wait: 10
    assert_text "Example Book"
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
    assert_selector "#pos_return_chooser li.is-selected", text: /Find Original Receipt/
    assert page.evaluate_script("document.activeElement === document.querySelector('#pos_return_chooser li.is-selected')")
    assert page.evaluate_script("document.querySelector('[data-register-workspace-target=background]').inert === true")
    send_keys :arrow_down
    send_keys :enter
    assert_selector "#pos_unlinked_overlay", visible: true
    assert_selector "#pos_return_chooser", visible: :all
    assert page.evaluate_script("document.querySelector('#pos_return_chooser').inert === true")
    send_keys :escape
    assert_no_selector "#pos_unlinked_overlay", visible: true
    assert_selector "#pos_return_chooser", visible: true
    send_keys :escape
    assert_no_selector "#pos_return_chooser", visible: true
    click_on "Return (-)"
    click_on "Continue"
    assert_selector "#pos_linked_overlay", visible: true
    assert_field "Receipt, merchandise, or unit"
    send_keys :escape
    assert_no_selector "#pos_linked_overlay", visible: true
    assert_selector "#pos_return_chooser", visible: true
    send_keys "-"
    assert_selector "#pos_return_chooser", visible: true
  end

  test "linked return Escape ladder restores stages then chooser" do
    open_register
    2.times do
      field = find("#pos-command-field")
      field.fill_in with: @variant.sku
      field.send_keys :enter
      start_cash_tender_via_plus
      field = find("#pos-command-field")
      field.fill_in with: "25.00"
      field.send_keys :enter
      send_keys :enter
      assert_text "Transaction complete", wait: 10
      click_on "New transaction"
      assert_text "SALE ENTRY", wait: 10
    end

    click_on "Return (-)"
    click_on "Continue"
    assert_selector "#pos_linked_overlay", visible: true
    field = find("[data-register-workspace-target='linkedLookupField']")
    field.fill_in with: @variant.sku
    click_on "Find Receipt"
    assert_selector "#pos_linked_overlay li", minimum: 2, wait: 10
    assert_button "View Returnable Items"
    click_on "View Returnable Items"
    assert_selector "[data-register-workspace-target='linkedPrimary']", text: "Add Return", wait: 10
    assert_selector "#pos_linked_overlay li", minimum: 1
    send_keys :escape
    assert_button "View Returnable Items"
    send_keys :escape
    assert_button "Find Receipt"
    assert_field "Receipt, merchandise, or unit"
    send_keys :escape
    assert_no_selector "#pos_linked_overlay", visible: true
    assert_selector "#pos_return_chooser", visible: true
    send_keys :escape
    assert_no_selector "#pos_return_chooser", visible: true
    assert_equal "pos-command-field", page.evaluate_script("document.activeElement && document.activeElement.id")
  end

  test "linked return Escape during lines fetch ignores the late response" do
    open_register
    2.times do
      field = find("#pos-command-field")
      field.fill_in with: @variant.sku
      field.send_keys :enter
      start_cash_tender_via_plus
      field = find("#pos-command-field")
      field.fill_in with: "25.00"
      field.send_keys :enter
      send_keys :enter
      assert_text "Transaction complete", wait: 10
      click_on "New transaction"
      assert_text "SALE ENTRY", wait: 10
    end

    click_on "Return (-)"
    click_on "Continue"
    field = find("[data-register-workspace-target='linkedLookupField']")
    field.fill_in with: @variant.sku
    click_on "Find Receipt"
    assert_selector "#pos_linked_overlay li", minimum: 2, wait: 10
    assert_button "View Returnable Items"

    page.evaluate_script(<<~JS.squish)
      (function() {
        window.__ssLinkedFetch = window.fetch.bind(window);
        window.__ssHoldLinkedLines = true;
        window.__ssDelayedLinked = null;
        window.fetch = function(input, init) {
          var url = "";
          if (typeof input === "string") url = input;
          else if (input && typeof input.url === "string") url = input.url;
          else if (input) url = String(input);
          if (window.__ssHoldLinkedLines && url.indexOf("linked_return_lookup") !== -1) {
            return new Promise(function(resolve) {
              window.__ssDelayedLinked = { resolve: resolve, init: init, input: input };
            });
          }
          return window.__ssLinkedFetch(input, init);
        };
      })()
    JS

    find("#pos_linked_overlay li.is-selected").send_keys :enter
    assert_text "Searching…", wait: 5
    assert page.evaluate_script("window.__ssDelayedLinked != null")
    send_keys :escape
    assert_button "Find Receipt"
    assert_field "Receipt, merchandise, or unit"

    page.execute_script(<<~JS.squish)
      (function() {
        window.__ssHoldLinkedLines = false;
        if (!window.__ssDelayedLinked) return;
        window.__ssLinkedFetch(window.__ssDelayedLinked.input, window.__ssDelayedLinked.init).then(function(response) {
          window.__ssDelayedLinked.resolve(response);
        });
        window.fetch = window.__ssLinkedFetch;
      })()
    JS
    sleep 0.5
    assert_button "Find Receipt"
    assert_selector "[data-register-workspace-target='linkedPrimary']", text: "Find Receipt"
    assert page.evaluate_script("document.activeElement === document.querySelector('[data-register-workspace-target=linkedLookupField]')")
  ensure
    page.execute_script("window.__ssHoldLinkedLines = false; if (window.__ssLinkedFetch) { window.fetch = window.__ssLinkedFetch; }")
  end

  test "prohibited unlinked return is disabled in the chooser" do
    role = Role.create!(key: "linked_only_#{SecureRandom.hex(3)}", name: "Linked only", assignment_scope: "store")
    RolePermission.create!(
      role: role,
      permission: Permission.find_by!(key: "pos.transact"),
      granted_by: @actor
    )
    user = User.create!(
      username: "linked_only_clerk",
      display_name: "Linked Only",
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    RoleAssignment.create!(
      user: user,
      role: role,
      store: @store,
      assigned_by: @actor,
      effective_at: Time.current
    )

    visit new_session_path
    fill_in "session_username", with: "linked_only_clerk"
    fill_in "session_password", with: "correct-horse-battery"
    find_field("session_password").send_keys :enter
    assert_text "Signed in successfully"
    visit pos_register_enter_path(register_id: @register.id)
    fill_in "Opening float", with: "0.00"
    click_on "Open register"
    assert_text "SALE ENTRY", wait: 10

    click_on "Return (-)"
    assert_selector "#pos_return_chooser li[data-choice='unlinked'].is-disabled", text: /Not available for your role/
    assert_selector "#pos_return_chooser li[data-choice='linked'].is-selected"
    send_keys :arrow_down
    assert_selector "#pos_return_chooser li[data-choice='linked'].is-selected"
    click_on "Continue"
    assert_selector "#pos_linked_overlay", visible: true
    assert_no_selector "#pos_unlinked_overlay", visible: true
  end

  test "linked return add via overlay clears return overlay ancestry" do
    open_register
    field = find("#pos-command-field")
    field.fill_in with: @variant.sku
    field.send_keys :enter
    start_cash_tender_via_plus
    field = find("#pos-command-field")
    field.fill_in with: "25.00"
    field.send_keys :enter
    send_keys :enter
    assert_text "Transaction complete", wait: 10
    sale = PosTransaction.completed.find_by!(register: @register)
    click_on "New transaction"
    assert_text "SALE ENTRY", wait: 10

    click_on "Return (-)"
    click_on "Continue"
    field = find("[data-register-workspace-target='linkedLookupField']")
    field.fill_in with: sale.transaction_reference
    click_on "Find Receipt"
    assert_selector "#pos_linked_overlay li.is-selected", wait: 10
    find("[data-register-workspace-target='linkedReasonField']").select "Changed mind"
    click_on "Add Return"
    assert_text "RETURN", wait: 10
    assert_no_selector "#pos_linked_overlay", visible: true
    assert_no_selector "#pos_return_chooser", visible: true
    assert_selector "tr.is-selected[data-direction='return']"
  end

  test "cashier attaches a customer from operational search overlay" do
    Customer.create!(display_name: "Overlay Customer", email: "overlay.customer@example.com")
    open_register
    click_on "Attach customer"
    assert_selector "#pos_customer_overlay", visible: true
    assert page.evaluate_script("document.activeElement === document.querySelector('[data-register-workspace-target=customerQueryField]')")
    field = find("[data-register-workspace-target='customerQueryField']")
    field.fill_in with: "Overlay Customer"
    field.send_keys :enter
    assert_selector "#pos_customer_overlay li", text: "Overlay Customer", wait: 10
    click_on "Attach Customer"
    assert_no_selector "#pos_customer_overlay", visible: true, wait: 10
    assert_text "Customer · Overlay Customer"
  end

  test "plus opens O11 after tenderability checks and restores sale on escape" do
    open_register
    find("#pos-command-field").send_keys "+"
    assert_text "Add merchandise before taking a tender."
    assert_no_selector "#pos_other_overlay", visible: true

    add_current_sku
    find("#pos-command-field").send_keys "+"
    assert_selector "#pos_other_overlay", visible: true
    assert_selector "#pos-other-title", text: "Add tender"
    assert_text "Back to Sale"
    assert_text "SALE ENTRY"
    send_keys :escape
    assert_no_selector "#pos_other_overlay", visible: true
    assert_text "SALE ENTRY"
    assert_equal "pos-command-field", page.evaluate_script("document.activeElement && document.activeElement.id")
  end

  test "O11 choose tender changes entry chrome only and F1 still bypasses O11" do
    open_register
    add_current_sku
    send_keys :f1
    assert_text "CASH TENDER"
    assert_no_selector "#pos_other_overlay", visible: true
    send_keys :escape
    assert_text "SALE ENTRY"

    click_on "Tender (+)"
    assert_selector "#pos_other_overlay", visible: true
    assert_selector "#pos_other_overlay li", text: "Cash"
    assert_selector "#pos_other_overlay li", text: "External Card"
    choose_tender_from_overlay("External Card")
    assert_text "TENDER"
    assert_selector "[data-register-workspace-target='fieldLabel']", text: /External Card/
    assert_equal 0, PosTransaction.working.find_by!(register: @register).pos_tenders.count
  end

  test "O11 escape from tender entry restores prior type and amount" do
    TenderType.create!(
      code: "voucher_restore",
      name: "Restore Voucher",
      behavioral_category: "other",
      external_reference_policy: "omitted",
      active: true
    )
    TenderType.create!(
      code: "campus_restore",
      name: "Restore Campus",
      behavioral_category: "other",
      external_reference_policy: "required",
      active: true
    )
    open_register
    add_current_sku
    send_keys :f4
    assert_selector "#pos_other_overlay", visible: true
    choose_tender_from_overlay("Restore Campus")
    assert_text "TENDER"
    field = find("#pos-command-field")
    field.fill_in with: "12.34"
    find("#pos-reference-field").fill_in with: "REF-9"
    send_keys :f4
    assert_selector "#pos_other_overlay", visible: true
    assert_text "Back to Tender"
    send_keys :escape
    assert_no_selector "#pos_other_overlay", visible: true
    assert_text "TENDER"
    assert_selector "[data-register-workspace-target='fieldLabel']", text: /Restore Campus/
    assert_equal "12.34", find("#pos-command-field").value
    assert_equal "REF-9", find("#pos-reference-field").value
  end

  test "applied split tenders survive O11 open and close" do
    TenderType.create!(
      code: "split_voucher",
      name: "Split Voucher",
      behavioral_category: "other",
      external_reference_policy: "omitted",
      active: true
    )
    TenderType.create!(
      code: "split_campus",
      name: "Split Campus",
      behavioral_category: "other",
      external_reference_policy: "omitted",
      active: true
    )
    open_register
    add_current_sku
    start_cash_tender_via_plus
    send_keys :f2
    field = find("#pos-command-field")
    field.fill_in with: "10.00"
    field.send_keys :enter
    assert_selector "#pos_tenders", text: "External Card"
    send_keys :f4
    assert_selector "#pos_other_overlay", visible: true
    send_keys :escape
    assert_no_selector "#pos_other_overlay", visible: true
    assert_selector "#pos_tenders", text: "External Card"
    assert_equal 1, PosTransaction.working.find_by!(register: @register).pos_tenders.count
  end

  test "O10 gift-card issuance add validates and persists activation" do
    GiftCards::Programs.seed!
    open_register
    click_on "Add gift card"
    assert_selector "#pos_issuance_overlay", visible: true
    assert page.evaluate_script("document.activeElement === document.getElementById('pos-issuance-amount')")
    select "Store generated", from: "pos-issuance-program"
    assert_selector "[data-register-workspace-target='issuanceCardWrap']", visible: :hidden
    find("#pos-issuance-amount").send_keys :enter
    assert_selector "#pos-issuance-feedback", text: /issuance amount/i
    assert_selector "#pos_issuance_overlay", visible: true
    find("#pos-issuance-amount").fill_in with: "25.00"
    find("#pos-issuance-amount").send_keys :enter
    assert_no_selector "#pos_issuance_overlay", visible: true, wait: 10
    assert_selector ".pos-issuance", text: /Activation/
    assert_selector ".pos-issuance", text: "$25.00"
    assert_equal 1, PosTransaction.working.find_by!(register: @register).pos_stored_value_issuances.count
  end

  test "O10 card visibility follows program authority and reload" do
    GiftCards::Programs.seed!
    open_register
    click_on "Add gift card"
    assert_selector "#pos_issuance_overlay", visible: true

    select "Store generated", from: "pos-issuance-program"
    select "Activation", from: "pos-issuance-type"
    assert_selector "[data-register-workspace-target='issuanceCardWrap']", visible: :hidden

    select "Reload", from: "pos-issuance-type"
    assert_selector "#pos-issuance-card", visible: true
    assert page.evaluate_script("document.activeElement === document.getElementById('pos-issuance-card')")

    find("#pos-issuance-card").fill_in with: "80100000000000000001"
    select "Activation", from: "pos-issuance-type"
    assert_selector "[data-register-workspace-target='issuanceCardWrap']", visible: :hidden
    assert_equal "", find("#pos-issuance-card", visible: :all).value

    select "Physical / external", from: "pos-issuance-program"
    assert_selector "#pos-issuance-card", visible: true
    assert page.evaluate_script("document.activeElement === document.getElementById('pos-issuance-program')")
    select "Activation", from: "pos-issuance-type"
    assert_selector "#pos-issuance-card", visible: true
    select "Reload", from: "pos-issuance-type"
    assert_selector "#pos-issuance-card", visible: true
  end

  test "O10 Enter on Program or Type does not submit" do
    GiftCards::Programs.seed!
    open_register
    click_on "Add gift card"
    assert_selector "#pos_issuance_overlay", visible: true
    find("#pos-issuance-amount").fill_in with: "10.00"
    find("#pos-issuance-program").click
    find("#pos-issuance-program").send_keys :enter
    assert_selector "#pos_issuance_overlay", visible: true
    assert_equal "", find("#pos-issuance-feedback").text
    assert_equal 0, PosTransaction.working.find_by!(register: @register).pos_stored_value_issuances.count
    find("#pos-issuance-type").click
    find("#pos-issuance-type").send_keys :enter
    assert_selector "#pos_issuance_overlay", visible: true
    assert_equal "", find("#pos-issuance-feedback").text
    assert_equal 0, PosTransaction.working.find_by!(register: @register).pos_stored_value_issuances.count
  end

  test "O10 Tab order is Amount Program Type then Card when required" do
    GiftCards::Programs.seed!
    open_register
    click_on "Add gift card"
    assert page.evaluate_script("document.activeElement === document.getElementById('pos-issuance-amount')")
    find("#pos-issuance-amount").send_keys :tab
    assert page.evaluate_script("document.activeElement === document.getElementById('pos-issuance-program')")
    select "Physical / external", from: "pos-issuance-program"
    assert page.evaluate_script("document.activeElement === document.getElementById('pos-issuance-program')")
    find("#pos-issuance-program").send_keys :tab
    assert page.evaluate_script("document.activeElement === document.getElementById('pos-issuance-type')")
    find("#pos-issuance-type").send_keys :tab
    assert page.evaluate_script("document.activeElement === document.getElementById('pos-issuance-card')")
  end

  test "O10 reload of system-generated card succeeds through scan-or-enter field" do
    GiftCards::Programs.seed!
    program = GiftCardProgram.find_by!(code: "generated")
    card = GiftCards::ProvisionInstrument.call(program: program, store: @store)
    GiftCards::Fund.call(gift_card: card, amount_cents: 500, store: @store, performed_by: @actor)
    number = card.number

    open_register
    click_on "Add gift card"
    find("#pos-issuance-amount").fill_in with: "10.00"
    select "Store generated", from: "pos-issuance-program"
    select "Reload", from: "pos-issuance-type"
    assert_selector "#pos-issuance-card", visible: true
    card_field = find("#pos-issuance-card")
    card_field.click
    card_field.send_keys number
    assert_equal number, card_field.value
    card_field.send_keys :enter
    assert_no_selector "#pos_issuance_overlay", visible: true, wait: 10
    assert_selector ".pos-issuance", text: /Reload/
    assert_selector ".pos-issuance", text: "$10.00"
    issuance = PosTransaction.working.find_by!(register: @register).pos_stored_value_issuances.sole
    assert_equal "reload", issuance.issuance_type
    assert_equal card.id, issuance.gift_card_id
  end

  test "O10 manual activation accepts card typed into focused scan field" do
    GiftCards::Programs.seed!
    program = GiftCardProgram.find_by!(code: "manual")
    number = GiftCards::Number.generate(program)
    open_register
    click_on "Add gift card"
    assert_selector "#pos_issuance_overlay", visible: true
    find("#pos-issuance-amount").fill_in with: "15.00"
    select "Physical / external", from: "pos-issuance-program"
    assert_selector "#pos-issuance-card", visible: true
    card_field = find("#pos-issuance-card")
    card_field.click
    card_field.send_keys number, :enter
    assert_no_selector "#pos_issuance_overlay", visible: true, wait: 10
    assert_selector ".pos-issuance", text: /Activation/
    assert_equal 1, PosTransaction.working.find_by!(register: @register).pos_stored_value_issuances.count
  end

  test "O11 tender rows are numbered for selection without scrolling" do
    open_register
    add_current_sku
    click_on "Tender (+)"
    assert_selector "#pos_other_overlay", visible: true
    assert_selector "#pos_other_overlay li.is-selected", text: /\A1\s+Cash\z/
    assert_selector "#pos_other_overlay li", text: /\A2\s+External Card\z/
    choose_tender_from_overlay("Cash")
    assert_text "CASH TENDER"
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

  def click_launcher_menu
    launcher = find("[data-register-shell-target='launcher']")
    page.execute_script("arguments[0].click()", launcher.native)
  end

  def command_field_top
    page.evaluate_script("document.getElementById('pos-command-field').getBoundingClientRect().top")
  end

  def selected_row_fully_in_basket?
    page.evaluate_script(<<~JS.squish)
      (function() {
        var basket = document.getElementById("pos_basket");
        var row = document.querySelector(".pos-lines tbody tr.is-selected");
        if (!basket || !row) return false;
        var basketBox = basket.getBoundingClientRect();
        var rowBox = row.getBoundingClientRect();
        return rowBox.top >= basketBox.top - 1 && rowBox.bottom <= basketBox.bottom + 1;
      })()
    JS
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
