# frozen_string_literal: true

require "test_helper"

class PosHomeTest < ActionDispatch::IntegrationTest
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
    @back = Register.create!(store: @store, register_number: 2, name: "Back")
    sign_in_as("admin")
  end

  test "get pos is session-free home and selling stays on register" do
    get pos_path
    assert_response :success
    assert_select "h1", text: "POS Home"
    assert_select "a", text: "Open Register"
    assert_select "a", text: "Transactions"
    assert_select "a", text: "X Report"
    assert_select "a", text: "Session / Z Reports"
    assert_select "a", text: "Switch Register"
    assert_select "a", text: "Return to ShelfSense"
    assert_select "a", text: "Active Sessions"
    refute_match "Scan or identifier", response.body
    refute_match "Management", response.body
    assert_equal 0, PosSession.count
    assert_equal 0, PosTransaction.count

    get pos_register_workspace_path
    assert_redirected_to pos_register_enter_path
  end

  test "home requires pos.transact" do
    User.create!(
      username: "no_pos",
      display_name: "No POS",
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    delete session_path
    post session_path, params: { session: { username: "no_pos", password: "correct-horse-battery" } }

    get pos_path
    assert_redirected_to root_path
  end

  test "preferred register cookie does not confer a session" do
    post pos_preferred_register_path, params: { register_id: @register.id }
    assert_redirected_to pos_path
    assert_equal 0, PosSession.count

    get pos_register_workspace_path
    assert_redirected_to pos_register_enter_path
    assert_equal 0, PosSession.count

    get pos_register_enter_path
    assert_response :success
    assert_select "select#register_id option[selected][value='#{@register.id}']"
    assert_equal 0, PosSession.count
  end

  test "resume register follows this cashier open session not a new preference" do
    front = pos_open_context(store: @store, actor: @actor, register: @register)
    post pos_preferred_register_path, params: { register_id: @back.id }
    follow_redirect!

    assert_select "a[href='#{pos_register_workspace_path(register_id: @register.id)}']", text: "Resume Register"
    assert_select "a", text: "Open Register", count: 0
    assert_equal front[:session].id, PosSession.open.find_by!(cashier_user: @actor).id

    get pos_register_enter_path
    assert_select "select#register_id option[selected][value='#{@back.id}']"
  end

  test "occupied preferred register stays selected and names the cashier" do
    Pos::EnterRegister.call(store: @store, register: @register, actor: @actor, opening_float_cents: 0)
    clerk = pos_transacting_user(store: @store, assigned_by: @actor, username: "home_clerk")
    delete session_path
    sign_in_as("home_clerk")

    post pos_preferred_register_path, params: { register_id: @register.id }
    follow_redirect!
    assert_match @actor.display_name, response.body
    assert_match "open for", response.body
    refute_match "Scan or identifier", response.body

    get pos_register_enter_path
    assert_response :success
    assert_select "select#register_id option[selected][value='#{@register.id}']"
    assert_match "is open for #{@actor.display_name}", response.body
    assert_select "input[type='submit'][value='Open register'][disabled]"
    assert_equal 1, PosSession.open.where(register: @register).count
  end

  test "switch register warns when a session is still open and does not close it" do
    pos_open_context(store: @store, actor: @actor, register: @register)
    get pos_switch_register_path
    assert_response :success
    assert_match "Register 01 is still open under your Session. Changing your preferred Register will not close it.", response.body

    post pos_preferred_register_path, params: { register_id: @back.id }
    assert_redirected_to pos_path
    assert PosSession.open.exists?(register: @register, cashier_user: @actor)
    refute PosSession.open.exists?(register: @back)
  end

  test "own x report is live totals and does not close" do
    context = pos_open_context(store: @store, actor: @actor, register: @register, opening_float_cents: 500)
    complete_cash_sale!(session: context[:session])

    get pos_x_report_path
    assert_response :success
    assert_match "X REPORT", response.body
    assert_match "INTERIM — SESSION REMAINS OPEN", response.body
    assert_select "h2", text: "Sales"
    assert_select "h2", text: "Returns"
    assert_select "h2", text: "Post-void"
    assert_select "h2", text: "Net"
    assert_select "h2", text: "Tenders"
    assert_select "h2", text: "Cash custody"
    assert_select "button", text: "Print"
    assert_select ".pos-report-print", text: /X REPORT/
    assert_match format_money_cents(500), response.body
    assert context[:session].reload.open?
    assert_nil context[:session].closed_at
    assert_nil context[:session].closing_count_cents
    assert_equal 1, PosSession.open.where(id: context[:session].id).count
  end

  test "pos.transact cannot open another cashiers live x" do
    pos_open_context(store: @store, actor: @actor, register: @register)
    clerk = pos_transacting_user(store: @store, assigned_by: @actor, username: "x_clerk")
    foreign = PosSession.open.find_by!(register: @register)
    delete session_path
    sign_in_as("x_clerk")

    get pos_path
    assert_response :success
    assert_select "a", text: "Active Sessions", count: 0

    get pos_x_report_path
    assert_redirected_to pos_path

    get pos_session_x_report_path(foreign)
    assert_response :not_found
    assert foreign.reload.open?

    get pos_active_sessions_path
    assert_response :not_found
  end

  test "sessions.view can open another cashiers x from active sessions" do
    pos_open_context(store: @store, actor: @actor, register: @register)
    manager = pos_store_manager(store: @store, assigned_by: @actor, username: "x_manager")
    foreign = PosSession.open.find_by!(register: @register)
    delete session_path
    sign_in_as("x_manager")

    get pos_path
    assert_response :success
    assert_select "a[href='#{pos_active_sessions_path}']", text: "Active Sessions"

    get pos_active_sessions_path
    assert_response :success
    assert_select "a[href='#{pos_session_x_report_path(foreign)}']", text: "X Report"

    get pos_session_x_report_path(foreign)
    assert_response :success
    assert_match "X REPORT", response.body
    assert_match @actor.display_name, response.body
    assert foreign.reload.open?
  end

  test "session and z reports are viewable without an open session" do
    context = pos_open_context(store: @store, actor: @actor, register: @register)
    Pos::CloseSession.call(
      session: context[:session],
      actor: @actor,
      expected_lock_version: context[:session].lock_version,
      closing_count_cents: 0
    )
    period = context[:period].reload
    Pos::FinalizeReportingPeriod.call(
      period: period,
      actor: @actor,
      expected_lock_version: period.lock_version
    )
    clerk = pos_transacting_user(store: @store, assigned_by: @actor, username: "report_clerk")
    delete session_path
    sign_in_as("report_clerk")

    refute PosSession.open.exists?(cashier_user: clerk)

    get pos_reports_path
    assert_response :success
    assert_select "a[href='#{pos_session_closed_path(context[:session])}']"
    assert_select "a[href='#{pos_reporting_period_z_path(context[:period])}']"

    get pos_session_closed_path(context[:session])
    assert_response :success
    assert_match "Session closed", response.body
    assert_nil session[:pos_register_id]

    get pos_reporting_period_z_path(context[:period])
    assert_response :success
    assert_match "Z report", response.body
    assert_select "h2", text: "Sales"
    assert_select "h2", text: "Cash custody"
    assert_select "button", text: "Print"
    assert_select ".pos-report-print"
  end

  test "workspace chrome is sparse" do
    post pos_register_enter_path, params: enter_params
    follow_redirect!
    assert_response :success
    assert_select "a", text: "POS Home"
    assert_select "a", text: "Transactions"
    assert_select "a", text: "X Report"
    assert_select "button, input[type=submit]", text: "Close register"
    refute_match "Return to ShelfSense", response.body
    refute_match "Switch Register", response.body
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

  def complete_cash_sale!(session:, actor: @actor, variant: @variant)
    transaction = Pos::StartTransaction.call(session: session, actor: actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: actor,
      expected_lock_version: transaction.lock_version,
      identifier: variant.sku
    )
    transaction.reload
    Pos::TenderCash.call(
      transaction: transaction,
      actor: actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: transaction.total_cents
    )
    transaction.reload
    Pos::CompleteTransaction.call(
      transaction: transaction,
      actor: actor,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents
    )
    transaction.reload
  end

  def format_money_cents(cents)
    sign = cents.negative? ? "-" : ""
    absolute = cents.abs
    "#{sign}$#{absolute / 100}.#{format("%02d", absolute % 100)}"
  end
end
