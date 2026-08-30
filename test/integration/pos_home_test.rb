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

  test "get pos is session-free selector and selling stays on register" do
    get pos_path
    assert_response :success
    assert_select "h1", text: "Select a Register"
    assert_select "a", text: "Transactions & Receipts"
    assert_select "a", text: "Session / Z Reports"
    assert_select "a", text: "Switch Register"
    assert_select "a", text: "X Report", count: 0
    assert_select "a", text: "Reverse cash", count: 0
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
    follow_redirect!
    assert_response :success
    assert_match "Open Register", response.body
    assert_select "input[name=register_id][value='#{@register.id}']", count: 1
    assert_equal 0, PosSession.count
  end

  test "resume register follows this cashier open session not a new preference" do
    front = pos_open_context(store: @store, actor: @actor, register: @register)
    post pos_preferred_register_path, params: { register_id: @back.id }
    follow_redirect!

    assert_select "h1", text: "Resume Register"
    assert_select "input[type='submit'][value='Resume Register']"
    assert_select "a", text: "Open Register", count: 0
    assert_equal front[:session].id, PosSession.open.find_by!(cashier_user: @actor).id

    get pos_register_enter_path
    follow_redirect!
    assert_select "h1", text: "Resume Register"
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
    follow_redirect!
    assert_response :success
    assert_match "is open for #{@actor.display_name}", response.body
    assert_select "h1", text: "Register in use"
    assert_equal 1, PosSession.open.where(register: @register).count
  end

  test "switch register warns when a session is still open and does not close it" do
    pos_open_context(store: @store, actor: @actor, register: @register)
    get pos_switch_register_path
    assert_response :success
    assert_match "Register 01 is still open under your Session. Changing your preferred Register will not close it.", response.body
    assert_select "#register-menu a", text: "Transactions & Receipts"
    assert_select "#register-menu a", text: "Switch Register", count: 0
    assert_select "#register-menu a", text: "X Report", count: 0

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
    assert_match "Expected Cash", response.body
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

  test "pos.sessions.view without pos.transact can open a foreign x" do
    pos_open_context(store: @store, actor: @actor, register: @register)
    foreign = PosSession.open.find_by!(register: @register)
    viewer = sessions_view_only_user(username: "x_viewer")
    delete session_path
    sign_in_as("x_viewer")

    get pos_path
    assert_redirected_to root_path

    get pos_x_report_path
    assert_redirected_to root_path

    get pos_active_sessions_path
    assert_response :success
    assert_select "a[href='#{pos_session_x_report_path(foreign)}']", text: "X Report"

    get pos_session_x_report_path(foreign)
    assert_response :success
    assert_match "X REPORT", response.body
    assert_match @actor.display_name, response.body
    assert foreign.reload.open?
    assert_equal viewer.id, User.find_by!(username: "x_viewer").id
  end

  test "session and z reports are viewable without an open session" do
    context = pos_open_context(store: @store, actor: @actor, register: @register)
    pos_close_session!(
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
    assert_select "a[href='#{pos_session_details_path(context[:session])}']"
    assert_select "a[href='#{pos_reporting_period_z_path(context[:period])}']"

    get pos_session_details_path(context[:session])
    assert_response :success
    assert_match "Closed Session Report", response.body
    assert_nil session[:pos_register_id]

    get pos_reporting_period_z_path(context[:period])
    assert_response :success
    assert_match "Z Report", response.body
    assert_select "h2", text: "Sales"
    assert_select "h2", text: "Cash custody"
    assert_select "button", text: "Print"
    assert_select ".pos-report-print"
  end

  test "workspace chrome uses the shared shell" do
    post pos_register_enter_path, params: enter_params
    follow_redirect!
    assert_response :success
    assert_select "a", text: "POS Home", count: 0
    assert_select "button", text: "F10 Menu"
    assert_select "a", text: "Transactions & Receipts"
    assert_select "a", text: "X Report"
    assert_select "a", text: "Switch Register"
    assert_select "button, input[type=submit]", text: "Close Session"
    assert_select "header.pos-header--register a[href='#{root_path}'][target=_blank]", count: 0
    assert_select "header.pos-header--register a[href='#{root_path}']", text: "Return to ShelfSense"
    assert_match "#{Pos::ReceiptIdentity.pad(@store.store_number, 3)} #{@store.name}", response.body
    assert_match "#{Pos::ReceiptIdentity.pad(@register.register_number, 2)} #{@register.name}", response.body
    assert_match(/Business Date \w{3} \d{2} \w{3} \d{2}/, response.body)
    assert_match "Opened:", response.body
    assert_select "header.pos-header--register", text: /#{Regexp.escape(@actor.display_name)}/
  end

  test "header business date language is state-aware" do
    get pos_path
    assert_response :success
    assert_match "Business date not selected", response.body
    refute_match(/Business Date \w{3}/, response.body)

    post pos_preferred_register_path, params: { register_id: @register.id }
    follow_redirect!
    assert_match "Business date not open", response.body
    assert_match "Proposed date:", response.body
    assert_select "a", text: "Return to ShelfSense"

    context = pos_open_context(store: @store, actor: @actor, register: @register, opening_float_cents: 0)
    pos_close_session!(session: context[:session], actor: @actor, closing_count_cents: 0)

    get pos_path(register_id: @register.id)
    assert_response :success
    assert_match "Open Session", response.body
    assert_match(/Business Date \w{3}/, response.body)
    refute_match "Proposed date:", response.body
    refute_match "Business date not open", response.body
    refute_match "Business date not selected", response.body

    other = pos_transacting_user(store: @store, assigned_by: @actor, username: "header_clerk")
    Pos::EnterRegister.call(store: @store, register: @register, actor: other, opening_float_cents: 0)
    get pos_path(register_id: @register.id)
    assert_response :success
    assert_match(/Business Date \w{3}/, response.body)
    assert_match(/open for|IN USE|In use/i, response.body)

    delete session_path
    sign_in_as("header_clerk")
    get pos_path(register_id: @register.id)
    follow_redirect! if response.redirect?
    assert_match(/Business Date \w{3}/, response.body)
    assert_match "Opened:", response.body
  end

  test "get pos does not mutate period session cash or transaction records" do
    context = pos_open_context(store: @store, actor: @actor, register: @register, opening_float_cents: 500)
    pos_session = context[:session]
    period = context[:period]
    safe = Cash::Locations.safe_for!(@store)
    dit = Cash::Locations.deposit_in_transit_for!(@store)

    snapshot = {
      period_count: PosReportingPeriod.count,
      session_count: PosSession.count,
      transaction_count: PosTransaction.count,
      cash_operation_count: CashOperation.count,
      cash_entry_count: CashEntry.count,
      period_lock: period.lock_version,
      period_date: period.business_date,
      period_status: period.status,
      session_lock: pos_session.lock_version,
      session_status: pos_session.status,
      session_float: pos_session.opening_float_cents,
      safe_lock: safe.lock_version,
      safe_expected: safe.expected_balance_cents,
      safe_initialized_at: safe.initialized_at,
      dit_lock: dit.lock_version,
      dit_expected: dit.expected_balance_cents
    }

    get pos_path
    assert_response :success

    period.reload
    pos_session.reload
    safe.reload
    dit.reload

    assert_equal snapshot[:period_count], PosReportingPeriod.count
    assert_equal snapshot[:session_count], PosSession.count
    assert_equal snapshot[:transaction_count], PosTransaction.count
    assert_equal snapshot[:cash_operation_count], CashOperation.count
    assert_equal snapshot[:cash_entry_count], CashEntry.count
    assert_equal snapshot[:period_lock], period.lock_version
    assert_equal snapshot[:period_date], period.business_date
    assert_equal snapshot[:period_status], period.status
    assert_equal snapshot[:session_lock], pos_session.lock_version
    assert_equal snapshot[:session_status], pos_session.status
    assert_equal snapshot[:session_float], pos_session.opening_float_cents
    assert_equal snapshot[:safe_lock], safe.lock_version
    assert_equal snapshot[:safe_expected], safe.expected_balance_cents
    assert_equal snapshot[:safe_initialized_at], safe.initialized_at
    assert_equal snapshot[:dit_lock], dit.lock_version
    assert_equal snapshot[:dit_expected], dit.expected_balance_cents
  end

  test "home treats multiple unbound owned sessions as a selector" do
    pos_open_context(store: @store, actor: @actor, register: @register)
    pos_open_context(store: @store, actor: @actor, register: @back)
    assert_equal 2, PosSession.open.where(cashier_user: @actor).count
    assert_nil session[:pos_register_id]

    post pos_preferred_register_path, params: { register_id: @register.id }
    get pos_path
    assert_response :success
    assert_select "h1", text: "Select a Register"
    assert_select "a", text: "Resume", count: 2
    assert_select "a[href='#{pos_register_workspace_path(register_id: @register.id)}']", text: "Resume"
    assert_select "a[href='#{pos_register_workspace_path(register_id: @back.id)}']", text: "Resume"
    assert_match "Your session", response.body
    assert_match "more than one open session", response.body
  end

  test "get register_id does not change the preferred register cookie" do
    post pos_preferred_register_path, params: { register_id: @register.id }
    follow_redirect!
    before = cookies[:pos_preferred_registers]

    get pos_path, params: { register_id: @back.id }
    assert_response :success
    assert_select "h1", text: "Open Register"
    assert_equal before, cookies[:pos_preferred_registers]
  end

  test "get enter redirect preserves flash" do
    get new_pos_cash_paid_in_path
    assert_redirected_to pos_path
    follow_redirect!
    assert_response :success
    assert_match "Open a register before recording cash activity.", response.body
  end

  test "closed and between sessions omit x report from the menu" do
    get pos_path, params: { register_id: @register.id }
    assert_select "a", text: "X Report", count: 0
    assert_select "a", text: "Session / Z Reports"
    assert_select "a", text: "Reverse cash", count: 0

    Pos::OpenReportingPeriod.call(store: @store, register: @register, actor: @actor)
    get pos_path, params: { register_id: @register.id }
    assert_select "h1", text: "Open Session"
    assert_select "a", text: "X Report", count: 0
    assert_select "input[type='submit'][value='Open session']"
    assert_select "input[type='submit'][value='Finalize Z']"
  end

  test "associate does not see expected cash on a live x report" do
    clerk = pos_transacting_user(store: @store, assigned_by: @actor, username: "x_blind")
    context = pos_open_context(store: @store, actor: clerk, register: @back, opening_float_cents: 500)
    delete session_path
    sign_in_as("x_blind")

    get pos_x_report_path
    assert_response :success
    refute_match "Expected Cash", response.body
    assert_match "Opening float", response.body
    assert context[:session].reload.open?
  end

  test "get pos does not write the preferred register cookie" do
    assert_nil cookies[:pos_preferred_registers]
    get pos_path
    assert_response :success
    assert_nil cookies[:pos_preferred_registers]

    get pos_path, params: { register_id: @register.id }
    assert_response :success
    assert_nil cookies[:pos_preferred_registers]
  end

  test "post enter failure stays on the submitted register" do
    post pos_preferred_register_path, params: { register_id: @back.id }
    follow_redirect!

    post pos_register_enter_path, params: enter_params(opening_float: "not-a-amount")
    assert_response :unprocessable_content
    assert_select "h1", text: "Open Register"
    assert_select "input[name=register_id][value='#{@register.id}']"
    assert_select "input[name=opening_float][value='not-a-amount']"
    refute_match "Register #{@back.admin_label} is open", response.body
    assert_equal 0, PosSession.count
  end

  test "manager sees expected cash on a live x report" do
    manager = pos_store_manager(store: @store, assigned_by: @actor, username: "x_expected")
    context = pos_open_context(store: @store, actor: manager, register: @back, opening_float_cents: 500)
    delete session_path
    sign_in_as("x_expected")

    get pos_x_report_path
    assert_response :success
    assert_match "Expected Cash", response.body
    assert context[:session].reload.open?
  end

  test "closed session report still shows expected closing cash" do
    context = pos_open_context(store: @store, actor: @actor, register: @register, opening_float_cents: 500)
    clerk = pos_transacting_user(store: @store, assigned_by: @actor, username: "close_view")
    pos_close_session!(
      session: context[:session],
      actor: @actor,
      expected_lock_version: context[:session].lock_version,
      closing_count_cents: 500
    )
    delete session_path
    sign_in_as("close_view")

    get pos_session_details_path(context[:session])
    assert_response :success
    assert_match "Expected closing Cash", response.body
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

  def sessions_view_only_user(username:)
    role = Role.create!(
      key: "session_viewer_#{SecureRandom.hex(4)}",
      name: "Session viewer #{SecureRandom.hex(4)}",
      assignment_scope: "either"
    )
    role.role_permissions.create!(
      permission: Permission.find_by!(key: "pos.sessions.view"),
      granted_by: @actor
    )
    user = User.create!(
      username: username,
      display_name: username,
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
    user
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
