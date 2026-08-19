# frozen_string_literal: true

require "test_helper"

class PosLinkedReturnWorkspaceTest < ActionDispatch::IntegrationTest
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
    @register = Register.create!(store: @store, register_number: 1, name: "Front")
    @context = pos_open_context(store: @store, actor: @actor, register: @register)
    @cash = TenderType.find_by!(code: "cash")
    @card = TenderType.find_by!(code: "card")
    sign_in_as("admin")
  end

  test "workspace marks linked returns and allows quantity with a copied historical discount" do
    sale = complete_discounted_sale!
    original_line = sale.pos_transaction_lines.first
    post pos_transaction_return_items_path(sale), params: selected_item(original_line, quantity: 1)
    follow_redirect!
    working = PosTransaction.working.find_by!(register: @register)
    return_line = working.pos_transaction_lines.first

    get pos_register_workspace_path
    assert_response :success
    assert_select "tr[data-direction='return'][data-linked-return='true']"
    assert_match "RETURN", response.body
    assert_match sale.transaction_reference, response.body
    assert_match "Refund due", response.body
    assert_match "Refund (+)", response.body

    post pos_register_quantity_path, params: {
      line_id: return_line.id,
      quantity: 2,
      lock_version: working.lock_version
    }
    assert_response :success
    assert_equal 2, return_line.reload.quantity

    post pos_register_controlled_action_path, params: {
      line_id: return_line.id,
      action_type: "price_override",
      operation: "apply",
      reason_code: "customer_service",
      selling_price: "1.00",
      lock_version: working.reload.lock_version
    }
    assert_response :success
    assert_match "controlled actions are sale-direction only", response.body

    post pos_register_remove_path, params: {
      line_id: return_line.id,
      lock_version: working.reload.lock_version
    }
    assert_response :success
    assert_equal 0, working.reload.pos_transaction_lines.count
  end

  test "used linked return quantity stays one" do
    _used_variant, unit = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax)
    sale = complete_unit_sale!(unit)
    post pos_transaction_return_items_path(sale), params: selected_item(sale.pos_transaction_lines.first)
    working = PosTransaction.working.find_by!(register: @register)
    return_line = working.pos_transaction_lines.first

    post pos_register_quantity_path, params: {
      line_id: return_line.id,
      quantity: 2,
      lock_version: working.lock_version
    }
    assert_response :success
    assert_match "quantity must be 1", response.body
    assert_equal 1, return_line.reload.quantity
  end

  test "cash refund completes with negative signed net and labels the receipt" do
    sale = complete_cash_sale!
    post pos_transaction_return_items_path(sale), params: selected_item(sale.pos_transaction_lines.first)
    follow_redirect!
    working = PosTransaction.working.find_by!(register: @register)
    refund_cents = -working.signed_net_cents

    get pos_register_workspace_path
    payload = JSON.parse(css_select("#pos_workspace").first["data-register-workspace-tender-types-value"])
    assert payload.all? { |row| row.fetch("allows_refund") }
    refute payload.any? { |row| row.fetch("category") == "check" }

    post pos_register_tender_path, params: {
      tender_amount: "500.00",
      lock_version: working.lock_version
    }
    assert_response :success
    assert_match "amount is greater than remaining refund", response.body
    assert_equal 0, working.reload.pos_tenders.count

    post pos_register_tender_path, params: {
      tender_amount: dollars(refund_cents),
      lock_version: working.lock_version
    }
    assert_response :success
    working.reload
    assert_equal 1, working.pos_tenders.count
    refund = working.pos_tenders.first
    assert_equal "refund", refund.direction
    assert_nil refund.amount_presented_cents
    assert_select "input[name='expected_total_cents'][value='#{working.total_cents}']"
    assert_select "input[name='expected_signed_net_cents'][value='#{working.signed_net_cents}']"

    operation_id = css_select("input[name='completion_operation_id']").first["value"]
    post pos_transaction_complete_path(working), params: {
      completion_operation_id: operation_id,
      lock_version: working.lock_version,
      expected_total_cents: working.total_cents,
      expected_signed_net_cents: working.signed_net_cents
    }
    assert_redirected_to pos_completed_transaction_path(working)
    follow_redirect!
    assert_match "Transaction complete", response.body
    assert_match "New transaction", response.body
    assert_match "Cash refund", response.body
    refute_match "Cash presented", response.body
    assert_match "Return from #{sale.transaction_reference}", response.body
    assert working.reload.completed?
    assert_equal(-refund_cents, working.signed_net_cents)

    get pos_transaction_path(working)
    assert_response :success
    assert_match format_signed(working.signed_net_cents), response.body
    assert_match "Cash refund", response.body
    commercial_before = commercial_counts
    get pos_transaction_path(working)
    assert_equal commercial_before, commercial_counts
  end

  test "external card refund can settle a linked return" do
    sale = complete_cash_sale!
    post pos_transaction_return_items_path(sale), params: selected_item(sale.pos_transaction_lines.first)
    working = PosTransaction.working.find_by!(register: @register)
    post pos_register_tender_path, params: {
      tender_amount: dollars(-working.signed_net_cents),
      tender_type_id: @card.id,
      external_reference: "REF-9",
      lock_version: working.lock_version
    }
    assert_response :success
    working.reload
    operation_id = css_select("input[name='completion_operation_id']").first["value"]
    post pos_transaction_complete_path(working), params: {
      completion_operation_id: operation_id,
      lock_version: working.lock_version,
      expected_total_cents: working.total_cents,
      expected_signed_net_cents: working.signed_net_cents
    }
    follow_redirect!
    assert_match "External Card refund", response.body
    assert_match "REF-9", response.body
  end

  test "zero-net mixed basket stays in sale entry until complete is confirmed" do
    sale = complete_cash_sale!(quantity: 1)
    post pos_register_enter_path, params: enter_params
    working = PosTransaction.working.find_by!(register: @register)
    post pos_register_merchandise_path, params: { identifier: @variant.sku, lock_version: working.lock_version }
    post pos_transaction_return_items_path(sale), params: selected_item(sale.pos_transaction_lines.first)
    working.reload
    assert_equal 0, working.signed_net_cents
    assert_equal 0, working.pos_tenders.count

    get pos_register_workspace_path
    assert_response :success
    assert working.reload.working?
    assert_match "SALE ENTRY", response.body
    assert_match "Even exchange", response.body
    assert_match "Complete (+)", response.body
    assert_match "Scan or identifier", response.body
    assert_select "[data-register-workspace-auto-complete-value='false']"
    assert_select "input[name='expected_signed_net_cents'][value='0']"

    post pos_register_merchandise_path, params: { identifier: @variant.sku, lock_version: working.lock_version }
    assert_response :success
    working.reload
    assert working.working?
    assert working.signed_net_cents.positive?
    assert_match "Amount due", response.body
  end

  test "even exchange completes with no tender after confirm" do
    sale = complete_cash_sale!(quantity: 1)
    post pos_register_enter_path, params: enter_params
    working = PosTransaction.working.find_by!(register: @register)
    post pos_register_merchandise_path, params: { identifier: @variant.sku, lock_version: working.lock_version }
    post pos_transaction_return_items_path(sale), params: selected_item(sale.pos_transaction_lines.first)
    working.reload
    assert_equal 0, working.signed_net_cents

    get pos_register_workspace_path
    operation_id = css_select("input[name='completion_operation_id']").first["value"]
    post pos_transaction_complete_path(working), params: {
      completion_operation_id: operation_id,
      lock_version: working.lock_version,
      expected_total_cents: working.total_cents,
      expected_signed_net_cents: 0
    }
    assert_redirected_to pos_completed_transaction_path(working)
    assert working.reload.completed?
    assert_equal 0, working.pos_tenders.count
  end

  test "closed session and z show returns refunds net and legacy nulls as not captured" do
    sale = complete_cash_sale!
    Pos::CloseSession.call(
      session: @context[:session],
      actor: @actor,
      expected_lock_version: @context[:session].lock_version,
      closing_count_cents: 0
    )
    return_register = Register.create!(store: @store, register_number: 2, name: "Returns")
    return_context = pos_open_context(store: @store, actor: @actor, register: return_register, opening_float_cents: 0)
    post pos_register_enter_path, params: {
      register_id: return_register.id,
      opening_float: "0.00",
      confirmed_business_date: return_context[:period].business_date.iso8601
    }
    post pos_transaction_return_items_path(sale), params: selected_item(sale.pos_transaction_lines.first)
    working = PosTransaction.working.find_by!(register: return_register)
    post pos_register_tender_path, params: {
      tender_amount: dollars(-working.signed_net_cents),
      lock_version: working.lock_version
    }
    working.reload
    operation_id = css_select("input[name='completion_operation_id']").first["value"]
    post pos_transaction_complete_path(working), params: {
      completion_operation_id: operation_id,
      lock_version: working.lock_version,
      expected_total_cents: working.total_cents,
      expected_signed_net_cents: working.signed_net_cents
    }
    session_record = return_context[:session]
    post pos_register_close_path, params: { session_id: session_record.id }
    follow_redirect!
    post pos_session_close_path(session_record), params: {
      closing_count: "0.00",
      expected_lock_version: session_record.lock_version
    }
    follow_redirect!
    session_record.reload
    assert session_record.closed?
    assert session_record.closing_expected_cash_cents.negative?
    assert_match "Returns total", response.body
    assert_match "Cash refunds", response.body
    assert_match "Net", response.body
    assert_match format_signed(session_record.closing_expected_cash_cents), response.body

    post pos_reporting_period_finalize_path(return_context[:period]), params: {
      expected_lock_version: return_context[:period].lock_version,
      return_to: "closed",
      session_id: session_record.id,
      register_id: return_register.id
    }
    follow_redirect!
    assert_match "Returns total", response.body
    assert_match "Cash refunds", response.body
    assert_match format_signed(session_record.closing_expected_cash_cents), response.body

    unused_register = Register.create!(store: @store, register_number: 9, name: "Legacy")
    unused = Pos::OpenReportingPeriod.call(store: @store, register: unused_register, actor: @actor)
    Pos::FinalizeReportingPeriod.call(
      period: unused,
      actor: @actor,
      expected_lock_version: unused.lock_version
    )
    PosReportingPeriod.where(id: unused.id).update_all(
      finalized_return_total_cents: nil,
      finalized_net_cents: nil,
      finalized_cash_refund_cents: nil
    )
    get pos_reporting_period_z_path(unused)
    assert_response :success
    assert_match "not captured", response.body
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

  def commercial_counts
    {
      transactions: PosTransaction.count,
      tenders: PosTender.count,
      ledger: InventoryLedgerEntry.count,
      outbox: OutboxMessage.count
    }
  end

  def complete_cash_sale!(quantity: 2)
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku,
      quantity: quantity
    )
    settle_and_complete!(transaction.reload)
  end

  def complete_discounted_sale!
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku,
      quantity: 2
    )
    transaction.reload
    Pos::ExecuteControlledAction.call(
      transaction: transaction,
      line: transaction.pos_transaction_lines.first,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      action_type: "line_discount",
      operation: "apply",
      reason_code: "customer_service",
      discount_basis_points: 1000
    )
    settle_and_complete!(transaction.reload)
  end

  def complete_unit_sale!(unit)
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: unit.unit_identifier
    )
    settle_and_complete!(transaction.reload)
  end

  def settle_and_complete!(transaction)
    Pos::TenderCash.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: transaction.total_cents
    )
    Pos::CompleteTransaction.call(
      transaction: transaction.reload,
      actor: @actor,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents
    )
    transaction.reload
  end
end
