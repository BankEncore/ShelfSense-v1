# frozen_string_literal: true

require "test_helper"

class PosMixedReturnWorkspaceTest < ActionDispatch::IntegrationTest
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
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 20)
    @thirty, @twenty = priced_variants(3000, 2000)
    @register = Register.create!(store: @store, register_number: 1, name: "Front")
    @cash = TenderType.find_by!(code: "cash")
    @card = TenderType.find_by!(code: "card")
    sign_in_as("admin")
  end

  test "workspace completes sale plus unlinked as payment refund and even exchange" do
    post pos_register_enter_path, params: enter_params
    follow_redirect!
    working = PosTransaction.working.find_by!(register: @register)

    post pos_register_merchandise_path, params: { identifier: @thirty.sku, lock_version: working.lock_version }
    post_unlinked!(working.reload, @twenty, "20.00")
    working.reload
    assert working.signed_net_cents.positive?
    assert_match "Amount due", response.body
    post pos_register_tender_path, params: {
      tender_amount: dollars(working.signed_net_cents),
      lock_version: working.lock_version
    }
    complete_working!(working.reload)
    follow_redirect!
    assert_match "Transaction complete", response.body
    assert_match "RETURN", response.body
    assert_match "Unlinked return", response.body
    assert_match "Net", response.body

    post pos_register_continue_path
    follow_redirect!
    working = PosTransaction.working.find_by!(register: @register)
    post pos_register_merchandise_path, params: { identifier: @twenty.sku, lock_version: working.lock_version }
    post_unlinked!(working.reload, @thirty, "30.00")
    working.reload
    assert working.signed_net_cents.negative?
    assert_match "Refund due", response.body
    post pos_register_tender_path, params: {
      tender_amount: dollars(-working.signed_net_cents),
      lock_version: working.lock_version
    }
    complete_working!(working.reload)
    follow_redirect!
    assert_match "Cash refund", response.body
    assert_match format_signed(working.reload.signed_net_cents), response.body
    refute_match "Cash presented", response.body

    post pos_register_continue_path
    follow_redirect!
    working = PosTransaction.working.find_by!(register: @register)
    post pos_register_merchandise_path, params: { identifier: @twenty.sku, lock_version: working.lock_version }
    post_unlinked!(working.reload, @twenty, "20.00")
    working.reload
    assert working.even_exchange?
    assert_equal 0, working.pos_tenders.count
    assert_match "Even exchange", response.body
    complete_working!(working)
    follow_redirect!
    assert_match "Transaction complete", response.body
    assert_equal 0, working.reload.pos_tenders.count
  end

  test "negative net split refund and positive net split payment complete from the workspace" do
    post pos_register_enter_path, params: enter_params
    follow_redirect!
    working = PosTransaction.working.find_by!(register: @register)
    post pos_register_merchandise_path, params: { identifier: @twenty.sku, lock_version: working.lock_version }
    post_unlinked!(working.reload, @thirty, "30.00")
    working.reload
    due = -working.signed_net_cents
    post pos_register_tender_path, params: {
      tender_amount: "4.00",
      tender_type_id: @card.id,
      external_reference: "REF-MIX",
      lock_version: working.lock_version
    }
    post pos_register_tender_path, params: {
      tender_amount: dollars(due - 400),
      tender_type_id: @cash.id,
      lock_version: working.reload.lock_version
    }
    complete_working!(working.reload)
    follow_redirect!
    assert_match "External Card refund", response.body
    assert_match "Cash refund", response.body
    completed = working.reload
    assert_equal %w[card cash], completed.pos_tenders.ordered.map(&:behavioral_category)
    assert(completed.pos_tenders.all? { |tender| tender.direction == "refund" })

    post pos_register_continue_path
    follow_redirect!
    working = PosTransaction.working.find_by!(register: @register)
    post pos_register_merchandise_path, params: { identifier: @thirty.sku, lock_version: working.lock_version }
    post_unlinked!(working.reload, @twenty, "20.00")
    working.reload
    post pos_register_tender_path, params: {
      tender_amount: "4.00",
      tender_type_id: @card.id,
      external_reference: "AUTH-MIX",
      lock_version: working.lock_version
    }
    post pos_register_tender_path, params: {
      tender_amount: dollars(working.reload.signed_net_cents - 400),
      tender_type_id: @cash.id,
      lock_version: working.reload.lock_version
    }
    complete_working!(working.reload)
    follow_redirect!
    completed = working.reload
    assert(completed.pos_tenders.all? { |tender| tender.direction == "payment" })
    assert_equal completed.signed_net_cents, completed.pos_tenders.sum(:amount_cents)
  end

  test "mixed receipt reprint and history keep snapshots after live catalog changes" do
    post pos_register_enter_path, params: enter_params
    follow_redirect!
    working = PosTransaction.working.find_by!(register: @register)
    add_http_sale!(working, @twenty)
    settle_http!(working.reload)
    complete_working!(working.reload)
    original = working.reload
    post pos_register_continue_path
    follow_redirect!
    working = PosTransaction.working.find_by!(register: @register)
    sale_line = add_http_sale!(working, @thirty)
    Pos::ExecuteControlledAction.call(
      transaction: working.reload,
      line: sale_line.reload,
      actor: @actor,
      expected_lock_version: working.lock_version,
      action_type: "line_discount",
      operation: "apply",
      reason_code: "customer_service",
      discount_basis_points: 1000
    )
    post_unlinked!(working.reload, @twenty, "15.00")
    post pos_transaction_return_items_path(original), params: selected_item(original.pos_transaction_lines.first)
    follow_redirect!
    working.reload
    settle_http!(working)
    complete_working!(working.reload)
    follow_redirect!
    completed = working.reload
    assert_match "RETURN", response.body
    assert_match "Unlinked return", response.body
    assert_match "Return from #{original.transaction_reference}", response.body
    assert_match "Net", response.body
    snapshot_title = completed.pos_transaction_lines.find(&:sale?).merchandise_snapshot.fetch("description")

    @thirty.product.update!(name: "Renamed Mixed Title")
    @thirty.update_columns(regular_price_cents: 1)
    TenderType.find_by!(code: "cash").update!(name: "Drawer Cash")
    @tax.update!(name: "Renamed Tax Class")

    get pos_transactions_path
    assert_response :success
    assert_match format_signed(completed.signed_net_cents), response.body

    get pos_transaction_path(completed)
    assert_response :success
    assert_match snapshot_title, response.body
    refute_match "Renamed Mixed Title", response.body
    assert_match "Unlinked return", response.body
    assert_match original.transaction_reference, response.body
    assert_select ".pos-history__detail", text: /Original receipt/
    assert_select ".pos-receipt__print", text: /Original: #{Regexp.escape(original.transaction_reference)}/
    assert_select ".pos-receipt__reprint", text: "*** REPRINT ***"
    assert_equal 0, Pos::Returnability.remaining_quantity(original.pos_transaction_lines.first)
  end

  test "other store cannot take linked original used unit history or refund" do
    used_variant, unit = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax)
    post pos_register_enter_path, params: enter_params
    follow_redirect!
    working = PosTransaction.working.find_by!(register: @register)
    add_http_sale!(working, unit)
    settle_http!(working.reload)
    complete_working!(working.reload)
    sale = working.reload

    east = Store.create!(store_number: "2", code: "east", name: "East Store", legal_name: "Example Books LLC", timezone: "America/New_York", country_code: "US")
    pos_transacting_user(store: east, assigned_by: @actor, username: "east_clerk")
    east_register = Register.create!(store: east, register_number: 1, name: "East Front")
    delete session_path
    sign_in_as("east_clerk")

    get pos_transaction_path(sale)
    assert_response :not_found

    post pos_transaction_return_items_path(sale), params: selected_item(sale.pos_transaction_lines.first)
    assert_response :not_found

    post pos_register_enter_path, params: {
      register_id: east_register.id,
      opening_float: "0.00",
      confirmed_business_date: BusinessDate.for_store(east).iso8601
    }
    follow_redirect!
    east_working = PosTransaction.working.find_by!(register: east_register)
    post pos_register_unlinked_return_path, params: {
      lock_version: east_working.lock_version,
      identifier: unit.unit_identifier,
      quantity: 1,
      reason_code: "changed_mind",
      return_price: "12.00"
    }
    assert_response :success
    assert_match(/not at this store|merchandise not found/i, response.body)
    assert_equal 0, east_working.reload.pos_transaction_lines.count
    assert used_variant.present?
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end

  def enter_params
    {
      register_id: @register.id,
      opening_float: "0.00",
      confirmed_business_date: BusinessDate.for_store(@store).iso8601
    }
  end

  def priced_variants(*prices)
    untaxed = tax_class(code: "untaxed_mixed_ui_#{SecureRandom.hex(3)}")
    StoreTaxes::EnsureRules.for_tax_class(untaxed)
    StoreTaxRule.find_by!(store_tax: StoreTax.find_by!(store: @store), tax_class: untaxed).update!(applies: false)
    prices.map.with_index do |cents, index|
      variant = pos_sellable_variant(actor: @actor, tax_class: untaxed, name: "Priced #{cents} #{index}")
      variant.update_columns(regular_price_cents: cents)
      open_quantity_stock(store: @store, variant: variant, actor: @actor, quantity: 20, unit_cost_cents: 100)
      variant
    end
  end

  def post_unlinked!(transaction, variant, return_price)
    post pos_register_unlinked_return_path, params: {
      lock_version: transaction.lock_version,
      identifier: variant.sku,
      quantity: 1,
      reason_code: "changed_mind",
      return_price: return_price,
      expected_product_variant_id: variant.id,
      expected_reference_unit_price_cents: variant.regular_price_cents,
      expected_tax_class_id: variant.tax_class_id
    }
    assert_response :success
  end

  def add_http_sale!(transaction, source)
    identifier = source.respond_to?(:sku) ? source.sku : source.unit_identifier
    post pos_register_merchandise_path, params: { identifier: identifier, lock_version: transaction.lock_version }
    assert_response :success
    transaction.reload.pos_transaction_lines.last
  end

  def settle_http!(transaction)
    if transaction.signed_net_cents.positive?
      post pos_register_tender_path, params: {
        tender_amount: dollars(transaction.signed_net_cents),
        lock_version: transaction.lock_version
      }
    elsif transaction.signed_net_cents.negative?
      post pos_register_tender_path, params: {
        tender_amount: dollars(-transaction.signed_net_cents),
        lock_version: transaction.lock_version
      }
    end
    assert_response :success
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
  end

  def selected_item(line, quantity: 1, reason_code: "changed_mind")
    {
      items: {
        line.id => {
          selected: "1",
          original_line_id: line.id,
          quantity: quantity,
          reason_code: reason_code,
          reason_note: ""
        }
      }
    }
  end

  def dollars(cents)
    "#{cents / 100}.#{format("%02d", cents % 100)}"
  end

  def format_signed(cents)
    return "$0.00" if cents.to_i.zero?

    prefix = cents.positive? ? "+" : "-"
    absolute = cents.abs
    "#{prefix}$#{absolute / 100}.#{format("%02d", absolute % 100)}"
  end
end
