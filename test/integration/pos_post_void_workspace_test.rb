# frozen_string_literal: true

require "test_helper"

class PosPostVoidWorkspaceTest < ActionDispatch::IntegrationTest
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
    Pos::TenderTypes.seed!
    sign_in_as("admin")
  end

  test "history offers post-void and completes to a post-void receipt" do
    sale = complete_cash_sale!

    get pos_transaction_path(sale)
    assert_response :success
    assert_select "a", text: "Post-void"
    assert_select "a", text: "Return items"

    get pos_transaction_post_void_path(sale)
    assert_response :success
    assert_match "Post-void", response.body
    assert_select "input[name='operation_id']"
    assert_select "input[name='reversal_transaction_id']"
    assert_select "input[name='approver_username']", count: 0

    operation_id = css_select("input[name='operation_id']").first["value"]
    reversal_id = css_select("input[name='reversal_transaction_id']").first["value"]
    post pos_transaction_post_void_path(sale), params: {
      operation_id: operation_id,
      reversal_transaction_id: reversal_id,
      reason_code: "entered_in_error"
    }
    reversal = PosTransaction.find(reversal_id)
    assert_redirected_to pos_completed_transaction_path(reversal)
    follow_redirect!
    assert_response :success
    assert_select ".pos-receipt__screen .pos-receipt__reprint", text: /POST-VOID of/
    assert_select ".pos-receipt__print .pos-receipt__reprint", text: /POST-VOID of/
    refute_match(/RETURN #{Regexp.escape("Example Book")}/, response.body)
    assert_match sale.transaction_reference, response.body

    get pos_transaction_path(sale)
    assert_response :success
    assert_select ".pos-history__detail .pos-receipt__reprint", text: "POST-VOIDED"
    assert_select ".pos-history__detail .pos-receipt__post-void-note",
                  text: "This transaction has been post-voided and is no longer valid."
    assert_select ".pos-history__detail", text: /Post-voided by/
    assert_select ".pos-receipt__print .pos-receipt__reprint", text: "POST-VOIDED"
    assert_select ".pos-receipt__print .pos-receipt__post-void-note",
                  text: "This transaction has been post-voided and is no longer valid."
    assert_select ".pos-receipt__print", text: /Post-voided by/, count: 0
    assert_select "a", text: reversal.transaction_reference
    assert_select "a", text: "Return items", count: 0
    assert_select "a", text: "Post-void", count: 0
  end

  test "idle empty register basket does not block post-void" do
    sale = complete_cash_sale!
    Pos::ResumeOrStartTransaction.call(session: @context[:session], actor: @actor)
    session[:pos_register_id] = @register.id

    get pos_transaction_post_void_path(sale)
    assert_response :success
    refute_match "Complete or cancel the current transaction before post-void.", response.body
    assert_select "input[type='submit'][value='Post-void']"

    post pos_transaction_post_void_path(sale), params: {
      operation_id: css_select("input[name='operation_id']").first["value"],
      reversal_transaction_id: css_select("input[name='reversal_transaction_id']").first["value"],
      reason_code: "entered_in_error"
    }
    reversal = PosTransaction.completed.find_by!(post_void_of_transaction_id: sale.id)
    assert_redirected_to pos_completed_transaction_path(reversal)
  end

  test "post-void get is read-only without a session and other store is not found" do
    sale = complete_cash_sale!
    clerk = pos_transacting_user(store: @store, assigned_by: @actor, username: "clerk_pv")
    delete session_path
    sign_in_as("clerk_pv")

    get pos_transaction_post_void_path(sale)
    assert_response :success
    assert_match "Open a register before processing a post-void.", response.body
    assert_select "input[type='submit'][value='Post-void']", count: 0

    post pos_transaction_post_void_path(sale), params: {
      operation_id: SecureRandom.uuid_v7,
      reversal_transaction_id: SecureRandom.uuid_v7,
      reason_code: "entered_in_error"
    }
    assert_response :unprocessable_entity
    assert_match "Open a register before processing a post-void.", response.body

    east = Store.create!(store_number: "2", code: "east", name: "East Store", timezone: "America/New_York", country_code: "US")
    pos_transacting_user(store: east, assigned_by: @actor, username: "east_pv")
    delete session_path
    sign_in_as("east_pv")
    get pos_transaction_post_void_path(sale)
    assert_response :not_found
  end

  test "associate post-void requires manager approval" do
    sale = complete_cash_sale!
    clerk = pos_transacting_user(store: @store, assigned_by: @actor, username: "clerk_approve_pv")
    pos_store_manager(store: @store, assigned_by: @actor, username: "mgr_pv")
    clerk_register = Register.create!(store: @store, register_number: 4, name: "Side")
    pos_open_context(store: @store, actor: clerk, register: clerk_register)
    delete session_path
    sign_in_as("clerk_approve_pv")

    get pos_transaction_post_void_path(sale)
    assert_response :success
    assert_select "input[name='approver_username']"

    post pos_transaction_post_void_path(sale), params: {
      operation_id: css_select("input[name='operation_id']").first["value"],
      reversal_transaction_id: css_select("input[name='reversal_transaction_id']").first["value"],
      reason_code: "test_transaction",
      approver_username: "mgr_pv",
      approver_password: "correct-horse-battery"
    }
    reversal = PosTransaction.completed.find_by!(post_void_of_transaction_id: sale.id)
    assert_redirected_to pos_completed_transaction_path(reversal)
    action = reversal.pos_controlled_actions.find_by!(action_type: "post_void")
    assert_equal "approval_required", action.policy_result
    assert_equal "mgr_pv", action.approved_by_user.username
  end

  test "card tender requires per-tender confirmation" do
    sale = complete_card_sale!("AUTH-1")
    card = sale.pos_tenders.find_by!(behavioral_category: "card")

    get pos_transaction_post_void_path(sale)
    assert_response :success
    assert_match "Card reversal confirmed", response.body

    post pos_transaction_post_void_path(sale), params: {
      operation_id: css_select("input[name='operation_id']").first["value"],
      reversal_transaction_id: css_select("input[name='reversal_transaction_id']").first["value"],
      reason_code: "duplicate_transaction"
    }
    assert_response :unprocessable_entity
    assert_match "Card reversal confirmation is required", response.body

    post pos_transaction_post_void_path(sale), params: {
      operation_id: css_select("input[name='operation_id']").first["value"],
      reversal_transaction_id: css_select("input[name='reversal_transaction_id']").first["value"],
      reason_code: "duplicate_transaction",
      card_reversals: {
        "0" => { source_tender_id: card.id, confirmed: "1", external_reference: "REV-9" }
      }
    }
    reversal = PosTransaction.completed.find_by!(post_void_of_transaction_id: sale.id)
    assert_redirected_to pos_completed_transaction_path(reversal)
    assert_equal "REV-9", reversal.pos_tenders.find_by!(behavioral_category: "card").external_reference
    refute_equal "AUTH-1", reversal.pos_tenders.find_by!(behavioral_category: "card").external_reference
  end

  test "closed session and z present post-void separately from returns" do
    sale = complete_cash_sale!
    get pos_transaction_post_void_path(sale)
    post pos_transaction_post_void_path(sale), params: {
      operation_id: css_select("input[name='operation_id']").first["value"],
      reversal_transaction_id: css_select("input[name='reversal_transaction_id']").first["value"],
      reason_code: "wrong_register"
    }
    follow_redirect!

    session_record = @context[:session]
    post pos_register_close_path, params: { session_id: session_record.id }
    follow_redirect!
    post pos_session_close_path(session_record), params: {
      closing_count: "0.00",
      expected_lock_version: session_record.reload.lock_version
    }
    follow_redirect!
    assert_response :success
    assert_match "Post-void adjustments", response.body
    assert_select "dt", text: "Returns total"
    body = response.body
    returns_dd = body[/<dt>Returns total<\/dt>\s*<dd>([^<]+)<\/dd>/, 1]
    assert_equal "$0.00", returns_dd

    period = session_record.reporting_period
    post pos_reporting_period_finalize_path(period), params: {
      expected_lock_version: period.lock_version,
      return_to: "closed",
      session_id: session_record.id,
      register_id: @register.id
    }
    follow_redirect!
    assert_response :success
    assert_match "Post-void adjustments", response.body
    refute_match "not captured", response.body[/<dt>Post-void adjustments<\/dt>\s*<dd>([^<]+)<\/dd>/, 1]
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end

  def complete_cash_sale!
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku
    )
    transaction.reload
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

  def complete_card_sale!(reference)
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku
    )
    transaction.reload
    Pos::AddTender.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      tender_type: TenderType.find_by!(code: "card"),
      amount_cents: transaction.total_cents,
      external_reference: reference
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
