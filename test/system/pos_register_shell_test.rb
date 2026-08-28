# frozen_string_literal: true

require "application_system_test_case"

class PosRegisterShellTest < ApplicationSystemTestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    @tax = tax_class(code: "shell_tax_#{SecureRandom.hex(2)}", name: "Shell tax")
    StoreTaxes::Create.call(
      store: @store,
      actor: @actor,
      name: "Shell State",
      rate_percent: "5.000",
      calculation_order: 1,
      applies_by_tax_class_id: { @tax.id => true }
    )
    @variant = pos_sellable_variant(actor: @actor, tax_class: @tax)
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 5)
    @registers = 12.times.map do |index|
      Register.create!(store: @store, register_number: index + 10, name: "Shell #{index}")
    end
    @register = @registers.first
  end

  test "selector remains scrollable and last action reachable at 200 percent zoom" do
    sign_in_admin(actor: @actor)
    visit pos_path
    assert_text "Select a Register"
    with_viewport(width: 1280, height: 720, zoom: 2) do
      assert shell_body_scrollable?
      last_view = all("a", text: "View").last
      scroll_to last_view
      assert last_view.visible?
      last_view.click
      assert_text "Open Register"
    end
  end

  test "switch register remains scrollable at 200 percent zoom" do
    sign_in_admin(actor: @actor)
    visit pos_switch_register_path
    assert_text "Switch Register"
    with_viewport(width: 1280, height: 720, zoom: 2) do
      assert shell_body_scrollable?
      last_preferred = all("input[type=submit][value='Make Preferred'], button", text: "Make Preferred").last
      scroll_to last_preferred
      assert last_preferred.visible?
    end
  end

  test "closed opening form with validation stays reachable at 200 percent zoom" do
    sign_in_admin(actor: @actor)
    visit pos_path(register_id: @register.id)
    assert_text "Open Register"
    fill_in "Opening float", with: "not-a-amount"
    click_on "Open register"
    assert_text(/Opening float|invalid|not a number|must be/i)
    with_viewport(width: 1280, height: 720, zoom: 2) do
      assert shell_body_scrollable?
      submit = find(:button, "Open register")
      scroll_to submit
      assert submit.visible?
    end
  end

  test "shell requests f10 keyboard lock outside the workspace" do
    sign_in_admin(actor: @actor)
    visit pos_path
    assert_text "Select a Register"
    install_keyboard_lock_recorder
    find("[data-register-shell-target='launcher']").click
    assert_equal [ "F10" ], last_keyboard_lock_keys
  end

  test "shell requests f1 through f10 keyboard lock on the workspace" do
    sign_in_admin(actor: @actor)
    visit pos_register_enter_path(register_id: @register.id)
    fill_in "Opening float", with: "0.00"
    click_on "Open register"
    assert_text "SALE ENTRY", wait: 10
    install_keyboard_lock_recorder
    find("#pos-command-field").click
    assert_equal %w[F1 F2 F3 F4 F5 F6 F7 F8 F9 F10], last_keyboard_lock_keys
  end

  test "typed identifiers still work when keyboard lock rejects" do
    sign_in_admin(actor: @actor)
    visit pos_register_enter_path(register_id: @register.id)
    fill_in "Opening float", with: "0.00"
    click_on "Open register"
    assert_text "SALE ENTRY", wait: 10
    page.execute_script(<<~JS)
      Object.defineProperty(navigator, "keyboard", {
        configurable: true,
        value: { lock: function() { return Promise.reject(new Error("denied")); }, unlock: function() {} }
      });
    JS
    find(".pos-header__cashier").click
    send_keys @variant.sku, :enter
    assert_selector "tbody tr.is-selected", text: "Example Book", wait: 10
  end

  test "f10 opens and closes the register menu on selector" do
    sign_in_admin(actor: @actor)
    visit pos_path
    assert_text "Select a Register"
    assert_f10_menu_lifecycle
  end

  test "f10 opens and closes the register menu on closed" do
    sign_in_admin(actor: @actor)
    visit pos_path(register_id: @register.id)
    assert_text "Open Register"
    assert_f10_menu_lifecycle
  end

  test "f10 opens and closes the register menu between sessions" do
    sign_in_admin(actor: @actor)
    context = pos_open_context(store: @store, actor: @actor, register: @register, opening_float_cents: 0)
    pos_close_session!(session: context[:session], actor: @actor, closing_count_cents: 0)
    visit pos_path(register_id: @register.id)
    assert_text "Open Session"
    assert_f10_menu_lifecycle
    open_register_menu
    assert_button "Open Session"
    assert_button "Finalize Z"
    send_keys :escape
  end

  test "f10 opens and closes the register menu on occupied" do
    other = pos_transacting_user(store: @store, assigned_by: @actor, username: "shell_occ")
    pos_open_context(store: @store, actor: other, register: @register, opening_float_cents: 0)
    sign_in_admin(actor: @actor)
    visit pos_path(register_id: @register.id)
    assert_text(/IN USE|open for/i)
    assert_f10_menu_lifecycle
    open_register_menu
    assert_link "X Report"
    send_keys :escape
  end

  test "f10 opens and closes the register menu on switch register" do
    sign_in_admin(actor: @actor)
    visit pos_switch_register_path
    assert_text "Switch Register"
    assert_f10_menu_lifecycle
    open_register_menu
    assert_no_selector "#register-menu a", text: "Switch Register"
    assert_no_selector "#register-menu a", text: "X Report"
    send_keys :escape
  end

  test "f10 opens and closes the register menu on the workspace" do
    sign_in_admin(actor: @actor)
    visit pos_register_enter_path(register_id: @register.id)
    fill_in "Opening float", with: "0.00"
    click_on "Open register"
    assert_text "SALE ENTRY", wait: 10
    find("#pos-command-field").click
    assert_f10_menu_lifecycle
    assert page.evaluate_script("document.activeElement === document.getElementById('pos-command-field')")
  end

  test "high zoom reaches the last register menu item" do
    sign_in_admin(actor: @actor)
    visit pos_path
    with_viewport(width: 1280, height: 720, zoom: 2) do
      open_register_menu
      last_item = all("#register-menu a, #register-menu button", visible: true).last
      scroll_to last_item
      assert last_item.visible?
    end
  end

  test "overlay text fields keep typed characters" do
    sign_in_admin(actor: @actor)
    visit pos_register_enter_path(register_id: @register.id)
    fill_in "Opening float", with: "0.00"
    click_on "Open register"
    assert_text "SALE ENTRY", wait: 10
    click_on "Return (-)"
    assert_selector "#pos_return_chooser", visible: true
    send_keys :enter
    assert_selector "#pos_linked_overlay", visible: true, wait: 10
    field = find("[data-register-workspace-target='linkedLookupField']")
    field.fill_in with: "ABC123"
    assert_equal "ABC123", field.value
  end

  private

  def install_keyboard_lock_recorder
    page.execute_script(<<~JS)
      window.__keyboardLockCalls = [];
      Object.defineProperty(navigator, "keyboard", {
        configurable: true,
        value: {
          lock: function(keys) {
            window.__keyboardLockCalls.push(Array.from(keys));
            return Promise.resolve();
          },
          unlock: function() {}
        }
      });
    JS
  end

  def keyboard_lock_calls
    page.evaluate_script("window.__keyboardLockCalls || []")
  end

  def last_keyboard_lock_keys
    keyboard_lock_calls.last
  end

  def assert_f10_menu_lifecycle
    assert_selector "[data-register-shell-target='launcher']"
    send_keys :f10
    assert_selector "#register-menu", visible: true
    assert_equal "true", find("[data-register-shell-target='launcher']")["aria-expanded"]
    assert page.evaluate_script("document.querySelector('.pos-register-shell__background').inert === true")
    assert page.evaluate_script("Boolean(document.activeElement && document.getElementById('register-menu').contains(document.activeElement))")
    send_keys :escape
    assert_selector "#register-menu", visible: :hidden
    assert_equal "false", find("[data-register-shell-target='launcher']")["aria-expanded"]
    assert page.evaluate_script("document.querySelector('.pos-register-shell__background').inert === false")
  end

  def shell_body_scrollable?
    page.evaluate_script(<<~JS.squish)
      (function() {
        var body = document.querySelector(".pos-register-shell__body");
        if (!body) return false;
        var style = window.getComputedStyle(body);
        return ["auto", "scroll", "overlay"].includes(style.overflowY) ||
          ["auto", "scroll", "overlay"].includes(style.overflow);
      })()
    JS
  end
end
