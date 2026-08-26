# frozen_string_literal: true

require "test_helper"

class PosMvpCloseoutTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    @tax = tax_class(code: "physical_book", name: "Physical book")
    @food = tax_class(code: "food_closeout", name: "Food")
    StoreTaxes::Create.call(
      store: @store,
      actor: @actor,
      name: "Illinois State",
      rate_percent: "5.000",
      calculation_order: 1,
      applies_by_tax_class_id: { @tax.id => true, @food.id => true }
    )
    @variant = pos_sellable_variant(actor: @actor, tax_class: @tax)
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 20)
    @non_inventory = pos_sellable_variant(
      actor: @actor,
      tax_class: @tax,
      inventory_mode: "non_inventory",
      name: "Gift Wrap"
    )
    @open_price = pos_sellable_variant(actor: @actor, tax_class: @tax, pricing_method: "open_price", name: "Open Book")
    open_quantity_stock(store: @store, variant: @open_price, actor: @actor, quantity: 3)
    _used_variant, @unit = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax)
    @register = Register.create!(store: @store, register_number: 1, name: "Front")
    @cash = TenderType.find_by!(code: "cash")
    @card = TenderType.find_by!(code: "card")
    sign_in_as("admin")
  end

  test "mvp closeout path through 6.7 modes print freeze returns post-void x and z" do
    get pos_path
    assert_response :success
    assert_select "h1", text: "POS Home"

    post pos_register_enter_path, params: enter_params(opening_float: "50.00")
    follow_redirect!
    assert_response :success
    working = PosTransaction.working.find_by!(register: @register)

    post pos_register_merchandise_path, params: { identifier: @variant.sku, lock_version: working.lock_version }
    assert_response :success
    standard_line = working.reload.pos_transaction_lines.find_by!(product_variant_id: @variant.id)
    post pos_register_merchandise_path, params: { identifier: @unit.unit_identifier, lock_version: working.lock_version }
    assert_response :success
    post pos_register_merchandise_path, params: { identifier: @non_inventory.sku, lock_version: working.reload.lock_version }
    assert_response :success
    assert working.reload.pos_transaction_lines.exists?(product_variant_id: @non_inventory.id)
    post pos_register_merchandise_path, params: {
      identifier: @open_price.sku,
      selling_price: "5.00",
      lock_version: working.reload.lock_version
    }
    assert_response :success

    post pos_register_controlled_action_path, params: {
      lock_version: working.reload.lock_version,
      line_id: standard_line.id,
      action_type: "price_override",
      operation: "apply",
      reason_code: "shelf_price_mismatch",
      selling_price: "15.00"
    }
    assert_response :success
    post pos_register_controlled_action_path, params: {
      lock_version: working.reload.lock_version,
      line_id: standard_line.id,
      action_type: "line_discount",
      operation: "apply",
      reason_code: "damaged",
      discount_percent: "10.00"
    }
    assert_response :success
    post pos_register_controlled_action_path, params: {
      lock_version: working.reload.lock_version,
      line_id: standard_line.id,
      action_type: "tax_class_override",
      operation: "apply",
      reason_code: "classification_correction"
    }
    assert_response :success

    working.reload
    post pos_register_tender_path, params: {
      tender_amount: "10.00",
      tender_type_id: @card.id,
      external_reference: "AUTH-CLOSEOUT",
      lock_version: working.lock_version
    }
    assert_response :success
    working.reload
    post pos_register_tender_path, params: {
      tender_amount: "200.00",
      tender_type_id: @cash.id,
      lock_version: working.lock_version
    }
    assert_response :success
    sale_a = complete_working!(working.reload)
    follow_redirect!
    assert_response :success
    assert_select "button", text: "Print receipt"
    assert_select ".pos-receipt__print"
    assert_select ".pos-receipt__print", text: /Business date/, count: 0
    assert_match "Gift Wrap", response.body
    assert_match "Open Book", response.body
    assert_match "External Card", response.body

    frozen_selling = format_money(standard_line.reload.selling_unit_price_cents)
    @variant.update_columns(regular_price_cents: 9999)
    @variant.product.update!(name: "Renamed Catalog Book")
    get pos_completed_transaction_path(sale_a)
    assert_response :success
    assert_match frozen_selling, response.body
    refute_match "Renamed Catalog Book", response.body
    refute_match "$99.99", response.body
    get pos_transaction_path(sale_a)
    assert_response :success
    assert_match frozen_selling, response.body
    refute_match "Renamed Catalog Book", response.body
    assert_match "Applied Tax Class", response.body
    assert_match "Performed by", response.body
    assert_select ".pos-receipt__reprint", text: "*** REPRINT ***"

    post pos_register_continue_path
    follow_redirect!
    working = PosTransaction.working.find_by!(register: @register)
    used_line = sale_a.pos_transaction_lines.detect { |line| line.merchandise_snapshot.is_a?(Hash) && line.merchandise_snapshot["unit_identifier"].present? }
    post pos_register_linked_return_path, params: {
      original_line_id: used_line.id,
      reason_code: "changed_mind",
      lock_version: working.lock_version
    }
    assert_response :success
    post pos_register_unlinked_return_path, params: {
      lock_version: working.reload.lock_version,
      identifier: @variant.sku,
      quantity: 1,
      reason_code: "changed_mind",
      return_price: "18.00",
      expected_product_variant_id: @variant.id,
      expected_reference_unit_price_cents: @variant.regular_price_cents,
      expected_tax_class_id: @variant.effective_tax_class&.id
    }
    assert_response :success
    working.reload
    assert working.signed_net_cents.negative?
    post pos_register_tender_path, params: {
      tender_amount: dollars(-working.signed_net_cents),
      tender_type_id: @cash.id,
      lock_version: working.lock_version
    }
    assert_response :success
    sale_b = complete_working!(working.reload)
    follow_redirect!
    assert_match "Unlinked return", response.body
    assert_match sale_a.transaction_reference, response.body
    assert sale_b.completed?

    post pos_register_continue_path
    follow_redirect!
    working = PosTransaction.working.find_by!(register: @register)
    post pos_register_merchandise_path, params: { identifier: @variant.sku, lock_version: working.lock_version }
    assert_response :success
    working.reload
    post pos_register_tender_path, params: {
      tender_amount: dollars(working.signed_net_cents),
      tender_type_id: @cash.id,
      lock_version: working.lock_version
    }
    sale_c = complete_working!(working.reload)

    get pos_transaction_post_void_path(sale_c)
    assert_response :success
    operation_id = css_select("input[name='operation_id']").first["value"]
    reversal_id = css_select("input[name='reversal_transaction_id']").first["value"]
    post pos_transaction_post_void_path(sale_c), params: {
      operation_id: operation_id,
      reversal_transaction_id: reversal_id,
      reason_code: "entered_in_error"
    }
    assert_redirected_to pos_completed_transaction_path(reversal_id)
    follow_redirect!
    assert_match "POST-VOID", response.body

    get pos_x_report_path
    assert_response :success
    assert_select "h2", text: "Sales"
    assert_select "h2", text: "Returns"
    assert_select "h2", text: "Post-void"
    assert_select "h2", text: "Net"
    assert_select "h2", text: "Tenders"
    assert_select "h2", text: "Cash custody"
    assert_select "button", text: "Print"
    session_record = PosSession.open.find_by!(register: @register)
    assert session_record.open?

    post pos_register_continue_path
    follow_redirect!
    post pos_register_close_path, params: { session_id: session_record.id }
    follow_redirect!
    assert_response :success
    assert_match "Closing Cash count", response.body
    refute_includes response.body, "Expected Cash"
    post pos_session_close_path(session_record), params: pos_close_http_params(
      closing_count: "0.00",
      expected_lock_version: session_record.lock_version
    )
    assert_redirected_to pos_session_closed_path(session_record)
    follow_redirect!
    assert_response :success
    session_record.reload
    assert session_record.closed?
    assert_match format_money(session_record.closing_expected_cash_cents), response.body
    assert_match format_money(session_record.closing_count_cents), response.body
    assert_match format_money(session_record.closing_variance_cents), response.body

    period = session_record.reporting_period
    post pos_reporting_period_finalize_path(period), params: {
      expected_lock_version: period.lock_version,
      return_to: "closed",
      session_id: session_record.id,
      register_id: @register.id
    }
    assert_redirected_to pos_reporting_period_z_path(period)
    follow_redirect!
    assert_response :success
    period.reload
    assert period.finalized?
    assert_match "Z report", response.body
    assert_select "h2", text: "Sales"
    assert_select "h2", text: "Cash custody"
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end

  def enter_params(opening_float: "0.00")
    {
      register_id: @register.id,
      opening_float: opening_float,
      confirmed_business_date: BusinessDate.for_store(@store).iso8601
    }
  end

  def complete_working!(transaction)
    operation_id = css_select("input[name='completion_operation_id']").first["value"]
    post pos_transaction_complete_path(transaction), params: {
      completion_operation_id: operation_id,
      lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents,
      expected_signed_net_cents: transaction.signed_net_cents
    }
    assert_redirected_to pos_completed_transaction_path(transaction)
    transaction.reload
  end

  def dollars(cents)
    format("%0.2f", cents / 100.0)
  end

  def format_money(cents)
    sign = cents.negative? ? "-" : ""
    absolute = cents.abs
    "#{sign}$#{absolute / 100}.#{format('%02d', absolute % 100)}"
  end
end
