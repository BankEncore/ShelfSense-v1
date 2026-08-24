# frozen_string_literal: true

require "application_system_test_case"

class UdsRegisterReferenceTest < ApplicationSystemTestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    @tax = tax_class(code: "uds_reg_#{SecureRandom.hex(3)}", name: "UDS register tax")
    StoreTaxes::Create.call(
      store: @store,
      actor: @actor,
      name: "UDS Register State",
      rate_percent: "5.000",
      calculation_order: 1,
      applies_by_tax_class_id: { @tax.id => true }
    )
    @variant = pos_sellable_variant(actor: @actor, tax_class: @tax)
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 5)
    @register = Register.create!(store: @store, register_number: 98, name: "UDS Register")
    sign_in_admin(actor: @actor)
    visit pos_register_enter_path(register_id: @register.id)
    fill_in "Opening float", with: "0.00"
    click_on "Open register"
    assert_text "SALE ENTRY", wait: 10
  end

  test "register sale entry passes axe and layout smoke" do
    assert_axe_clean(surface: :register)
    uds_layout_smoke(
      surface: :register,
      scroll_selector: ".pos-basket",
      layout_options: {
        per_viewport: {
          "320x568" => { check_clipped: false, check_overflow: false },
          "zoom-2x" => { check_clipped: false, check_overflow: false },
          "zoom-4x" => { check_clipped: false, check_overflow: false }
        }
      }
    )
    assert_reduced_motion_smoke(surface: :register)
    assert_forced_colors_smoke(surface: :register)
  end

  test "register scan workflow preserves correctness without pointer" do
    field = find("#pos-command-field")
    field.fill_in with: @variant.sku
    field.send_keys :enter
    assert_text "Example Book"
    field.fill_in with: @variant.sku
    field.send_keys :enter
    assert_selector "tr.is-selected[data-quantity='2']", wait: 5

    click_on "Tender (+)"
    field = find("#pos-command-field")
    field.fill_in with: "50.00"
    field.send_keys :enter
    send_keys :enter

    assert_text "Transaction complete", wait: 10
    assert_equal 1, PosTransaction.completed.where(register: @register).count
  end

  test "register cancel overlay ignores enter and confirms on f9" do
    add_line
    send_keys :f9
    assert_text "Cancel this transaction?"
    send_keys :enter
    assert_text "Cancel this transaction?"
    assert_text "Example Book"
    send_keys :f9
    assert_text "SALE ENTRY"
    assert_no_text "Transaction complete"
  end

  private

  def add_line
    field = find("#pos-command-field")
    field.fill_in with: @variant.sku
    field.send_keys :enter
    assert_text "Example Book"
  end
end
