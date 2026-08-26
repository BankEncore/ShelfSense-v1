# frozen_string_literal: true

require "test_helper"

class PosGiftCardVoucherTest < ActionDispatch::IntegrationTest
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
    @register = Register.create!(store: @store, register_number: 1, name: "Front")
    GiftCards::Programs.seed!
    Pos::TenderTypes.seed!
    @program = GiftCardProgram.find_by!(code: "generated")
    @store.update!(
      street_address_1: "1234 Any Street",
      city: "Any Town",
      region_code: "MI",
      postal_code: "99999",
      phone: "586-555-9999"
    )
    SystemSettings.current.update!(gift_card_voucher_footer: "Redeemable at Example Books LLC.\nTreat this voucher like cash.")
    sign_in_as("admin")
  end

  test "first completed view prints a voucher once and ordinary receipt stays masked" do
    post pos_register_enter_path, params: enter_params
    follow_redirect!
    transaction = PosTransaction.working.find_by!(register: @register)
    post pos_register_stored_value_issuance_path, params: {
      register_id: @register.id,
      lock_version: transaction.lock_version,
      issuance_type: "activation",
      gift_card_program_id: @program.id,
      issuance_amount: "10.00"
    }
    post pos_register_tender_path, params: { tender_amount: "10.00", lock_version: transaction.reload.lock_version }
    operation_id = css_select("input[name='completion_operation_id']").first["value"]
    post pos_transaction_complete_path(transaction), params: {
      completion_operation_id: operation_id,
      lock_version: transaction.reload.lock_version,
      expected_total_cents: transaction.total_cents,
      expected_signed_net_cents: transaction.signed_net_cents,
      amount_presented_cents: 1000
    }
    follow_redirect!
    card = transaction.reload.pos_stored_value_issuances.sole.gift_card
    presented = GiftCards::Number.present(card.number, prefix: card.number_prefix)
    voucher = css_select(".pos-gift-card-voucher").first
    receipt = css_select(".pos-receipt__print").first
    assert voucher
    assert_includes voucher.text, @store.legal_name
    assert_includes voucher.text, "1234 Any Street"
    assert_includes voucher.text, "Issued:"
    assert_includes voucher.text, "$10.00"
    assert_includes voucher.text, "Gift Card"
    assert_includes voucher.text, presented
    refute_includes voucher.text, card.number
    barcode = css_select(".pos-gift-card-voucher svg").first
    assert barcode
    assert_equal card.number, barcode["aria-label"]
    assert_includes voucher.to_html, card.number
    assert_includes voucher.text, "Redeemable at Example Books LLC."
    assert_includes voucher.text, "Treat this voucher like cash."
    refute_includes voucher.text, "Store generated"
    refute_includes voucher.text, "Activation"
    assert_match "Print gift card", response.body
    assert_match(/no-store/, response.headers["Cache-Control"].to_s)
    refute_includes receipt.text, card.number
    refute_includes receipt.text, presented
    refute_includes receipt.text, "Treat this voucher like cash."
    assert_includes receipt.text, card.masked_number
    receipt_svgs = css_select(".pos-receipt__print svg")
    refute receipt_svgs.any? { |svg| svg["aria-label"] == card.number }

    get pos_completed_transaction_path(transaction)
    assert_response :success
    refute_includes response.body, card.number
    assert_no_match "Print gift card", response.body

    get pos_transaction_path(transaction)
    assert_response :success
    refute_includes response.body, card.number
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end

  def enter_params
    {
      register_id: @register.id,
      opening_float: "50.00",
      confirmed_business_date: BusinessDate.for_store(@store).iso8601
    }
  end
end
