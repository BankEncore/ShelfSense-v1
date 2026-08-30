# frozen_string_literal: true

require "application_system_test_case"

class PosCashReversalOverlaySystemTest < ApplicationSystemTestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    Cash::ActivityReasons.seed!
    @register = Register.create!(store: @store, register_number: 55, name: "O19")
    @context = pos_open_context(store: @store, actor: @actor, register: @register, opening_float_cents: 10_000)
    @paid_in = Cash::PaidIn.call(
      session: @context[:session],
      actor: @actor,
      amount_cents: 350,
      reason_code: "paid_in_found",
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    )
  end

  test "O19 opens with focus trap inert detail F10 suppression Escape and launcher restore" do
    sign_in_admin(actor: @actor)
    visit pos_cash_operation_path(@paid_in.cash_operation, register_id: @register.id)
    assert_text "Paid in"
    assert_selector "#pos_cash_reversal_overlay", visible: :hidden

    find("button", text: "Reverse").click

    find("#pos_cash_reversal_overlay", visible: true)
    assert page.evaluate_script("document.getElementById('pos_cash_operation_detail').inert === true")
    assert page.evaluate_script("document.querySelector('[data-register-shell-target=header]').inert === true")
    assert page.evaluate_script("Boolean(document.activeElement && document.getElementById('pos_cash_reversal_overlay').contains(document.activeElement))")

    send_keys :f10
    assert_selector "#register-menu", visible: :hidden

    send_keys [ :shift, :tab ]
    assert page.evaluate_script("document.getElementById('pos_cash_reversal_overlay').contains(document.activeElement)")
    send_keys :tab
    assert page.evaluate_script("document.getElementById('pos_cash_reversal_overlay').contains(document.activeElement)")

    send_keys :escape
    assert_selector "#pos_cash_reversal_overlay", visible: :hidden
    assert page.evaluate_script("document.getElementById('pos_cash_operation_detail').inert === false")
    assert_equal "Reverse", page.evaluate_script("document.activeElement && document.activeElement.textContent.trim()")

    find("button", text: "Reverse").click
    click_on "Keep Original Operation"
    assert_selector "#pos_cash_reversal_overlay", visible: :hidden
    assert_equal "Reverse", page.evaluate_script("document.activeElement && document.activeElement.textContent.trim()")
    refute @paid_in.cash_operation.reload.reversed?
  end
end
