# frozen_string_literal: true

require "test_helper"

class PosCloseZTest < ActionDispatch::IntegrationTest
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
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 10)
    @register = Register.create!(store: @store, register_number: 1, name: "Front")
    sign_in_as("admin")
  end

  test "completed receipt exposes print and close without mutating on get" do
    transaction = complete_http_sale(opening_float: "100.00")
    get pos_completed_transaction_path(transaction)
    assert_response :success
    assert_select "button", text: "Print receipt"
    assert_match "New sale", response.body
    assert_match "Close register", response.body
    assert_match "Store: 001   Reg: 01   Trans:", response.body
    assert_match "Example Book", response.body
    assert_select ".pos-print-only"
    assert_select ".pos-no-print"
    assert transaction.reload.completed?
    assert_equal 1, PosTransaction.completed.where(id: transaction.id).count
  end

  test "empty sale entry can initiate close and cancel the empty ticket" do
    post pos_register_enter_path, params: enter_params(opening_float: "100.00")
    follow_redirect!
    assert_match "Close register", response.body
    transaction = PosTransaction.working.find_by!(register: @register)
    session_record = transaction.pos_session

    post pos_register_close_path
    assert_redirected_to pos_session_close_path(session_record)
    assert transaction.reload.cancelled?
    follow_redirect!
    assert_response :success
    assert_match "Closing Cash count", response.body
    refute_includes response.body, "Expected"
    refute_includes response.body, "Opening float"
    refute_includes response.body, "$100.00"
    refute_includes response.body, "Variance"
    refute_includes response.body, "Cash payments"
    assert_select "input[name='expected_lock_version'][value='#{session_record.reload.lock_version}']"
  end

  test "nonempty sale cannot initiate close" do
    post pos_register_enter_path, params: enter_params
    transaction = PosTransaction.working.find_by!(register: @register)
    post pos_register_merchandise_path, params: { identifier: @variant.sku, lock_version: transaction.lock_version }
    get pos_register_workspace_path
    assert_no_match "Close register", response.body

    post pos_register_close_path
    assert_redirected_to pos_register_workspace_path
    follow_redirect!
    assert_match "Complete or cancel the current sale before closing.", response.body
    assert transaction.reload.working?
  end

  test "repeating initiate close after empty cancel still reaches the count screen" do
    post pos_register_enter_path, params: enter_params
    session_record = PosSession.open.find_by!(register: @register)
    post pos_register_close_path
    assert_redirected_to pos_session_close_path(session_record)
    post pos_register_close_path
    assert_redirected_to pos_session_close_path(session_record)
    assert_equal 0, session_record.pos_transactions.working.count
  end

  test "get close does not cancel a merchandised working transaction" do
    post pos_register_enter_path, params: enter_params
    transaction = PosTransaction.working.find_by!(register: @register)
    post pos_register_merchandise_path, params: { identifier: @variant.sku, lock_version: transaction.lock_version }
    session_record = transaction.pos_session

    get pos_session_close_path(session_record)
    assert_redirected_to pos_register_workspace_path
    assert transaction.reload.working?
    assert_equal 1, transaction.pos_transaction_lines.count
  end

  test "zero dollars closes and reveals persisted snapshots" do
    complete_http_sale(opening_float: "100.00")
    session_record = PosSession.open.find_by!(register: @register)
    post pos_register_close_path
    follow_redirect!

    post pos_session_close_path(session_record), params: {
      closing_count: "0.00",
      expected_lock_version: session_record.lock_version
    }
    assert_redirected_to pos_session_closed_path(session_record)
    follow_redirect!
    assert_response :success
    session_record.reload
    assert session_record.closed?
    assert_equal 0, session_record.closing_count_cents
    assert_equal session_record.opening_float_cents + Pos::SessionTotals.for(session_record).cash_tender_cents,
                 session_record.closing_expected_cash_cents
    assert_match format_money(session_record.closing_expected_cash_cents), response.body
    assert_match format_money(session_record.closing_count_cents), response.body
    assert_match format_money(session_record.closing_variance_cents), response.body
    assert_match "Finalize Z", response.body
    assert_match "Leave period open", response.body
    assert PosReportingPeriod.open.exists?(register: @register)
  end

  test "invalid and stale still-open counts stay blind and preserve input" do
    post pos_register_enter_path, params: enter_params(opening_float: "100.00")
    session_record = PosSession.open.find_by!(register: @register)
    post pos_register_close_path
    follow_redirect!

    post pos_session_close_path(session_record), params: {
      closing_count: "abc",
      expected_lock_version: session_record.lock_version
    }
    assert_response :unprocessable_content
    assert_match "Closing Cash count", response.body
    assert_select "#closing_count[value='abc']"
    refute_includes response.body, "$100.00"
    refute_includes response.body, "Expected"
    refute_includes response.body, "Variance"

    PosSession.where(id: session_record.id).update_all("lock_version = lock_version + 1")
    post pos_session_close_path(session_record), params: {
      closing_count: "12.34",
      expected_lock_version: session_record.lock_version
    }
    assert_response :unprocessable_content
    assert_match "Closing Cash count", response.body
    assert_select "#closing_count[value='12.34']"
    refute_includes response.body, "$100.00"
    assert session_record.reload.open?
  end

  test "already closed close post redirects without a second audit" do
    complete_http_sale
    session_record = PosSession.open.find_by!(register: @register)
    Pos::CloseSession.call(
      session: session_record,
      actor: @actor,
      expected_lock_version: session_record.lock_version,
      closing_count_cents: 0
    )
    assert_equal 1, AuditEvent.where(action: "pos.session.closed", subject_type: "PosSession", subject_id: session_record.id).count

    post pos_session_close_path(session_record), params: {
      closing_count: "0.00",
      expected_lock_version: session_record.lock_version
    }
    assert_redirected_to pos_session_closed_path(session_record)
    assert_equal 1, AuditEvent.where(action: "pos.session.closed", subject_type: "PosSession", subject_id: session_record.id).count
  end

  test "return to sales resumes an empty working transaction" do
    post pos_register_enter_path, params: enter_params
    session_record = PosSession.open.find_by!(register: @register)
    post pos_register_close_path
    follow_redirect!

    post pos_session_resume_sales_path(session_record)
    assert_redirected_to pos_register_workspace_path
    follow_redirect!
    assert_match "SALE ENTRY", response.body
    assert session_record.pos_transactions.working.exists?
  end

  test "leave period open returns to the enter gate for that register" do
    complete_http_sale
    session_record = PosSession.open.find_by!(register: @register)
    Pos::CloseSession.call(
      session: session_record,
      actor: @actor,
      expected_lock_version: session_record.lock_version,
      closing_count_cents: 0
    )
    get pos_session_closed_path(session_record)
    assert_select "a[href='#{pos_register_enter_path(register_id: @register.id)}']", text: "Leave period open"

    get pos_register_enter_path(register_id: @register.id)
    assert_response :success
    assert_match "Finalize Z", response.body
    assert_match "Open session", response.body
    assert PosReportingPeriod.open.exists?(register: @register)
    assert_equal 0, PosSession.open.where(register: @register).count
  end

  test "open current-date period with no session offers finalize z and open session" do
    Pos::OpenReportingPeriod.call(store: @store, register: @register, actor: @actor)
    get pos_register_enter_path, params: { register_id: @register.id }
    assert_response :success
    assert_match "Finalize Z", response.body
    assert_match "Open session", response.body
    assert_select "input[name='expected_lock_version']"
  end

  test "leftover period with no session offers the same actions and a conspicuous date" do
    period = Pos::OpenReportingPeriod.call(store: @store, register: @register, actor: @actor)
    leftover_date = period.business_date
    travel_to Time.current + 1.day do
      UserSession.where(user: @actor).update_all(last_seen_at: Time.current)
      get pos_register_enter_path, params: { register_id: @register.id }
      assert_response :success
      assert_match "This register is still on business date #{leftover_date.iso8601}.", response.body
      assert_match "Finalize Z", response.body
      assert_match "Open session", response.body
    end
  end

  test "open session resumes the existing leftover period" do
    period = Pos::OpenReportingPeriod.call(store: @store, register: @register, actor: @actor)
    leftover_date = period.business_date
    travel_to Time.current + 1.day do
      UserSession.where(user: @actor).update_all(last_seen_at: Time.current)
      post pos_register_enter_path, params: {
        register_id: @register.id,
        opening_float: "25.00"
      }
      assert_redirected_to pos_register_workspace_path
      session_record = PosSession.open.find_by!(register: @register)
      assert_equal period.id, session_record.reporting_period_id
      assert_equal leftover_date, session_record.reporting_period.business_date
      assert_equal 1, PosReportingPeriod.where(register: @register).count
    end
  end

  test "unused period can be finalized from the enter gate as an all-zero z" do
    period = Pos::OpenReportingPeriod.call(store: @store, register: @register, actor: @actor)
    post pos_reporting_period_finalize_path(period), params: {
      expected_lock_version: period.lock_version,
      return_to: "enter",
      register_id: @register.id
    }
    assert_redirected_to pos_reporting_period_z_path(period)
    follow_redirect!
    assert_response :success
    period.reload
    assert period.finalized?
    assert_equal 0, period.finalized_session_count
    assert_equal 0, period.finalized_transaction_count
    assert_match "Z report", response.body
    assert_match "Sessions", response.body
    assert_match format_money(0), response.body
    assert_match "Store  001", response.body
    assert_match "Register  01", response.body
    assert_match format_store_zone(period.closed_at), response.body
  end

  test "repeated finalize redirects to the existing z without a second audit" do
    period = Pos::OpenReportingPeriod.call(store: @store, register: @register, actor: @actor)
    post pos_reporting_period_finalize_path(period), params: {
      expected_lock_version: period.lock_version,
      return_to: "enter",
      register_id: @register.id
    }
    assert_equal 1, AuditEvent.where(action: "pos.reporting_period.finalized", subject_type: "PosReportingPeriod", subject_id: period.id).count

    post pos_reporting_period_finalize_path(period), params: {
      expected_lock_version: period.lock_version,
      return_to: "enter",
      register_id: @register.id
    }
    assert_redirected_to pos_reporting_period_z_path(period)
    assert_equal 1, AuditEvent.where(action: "pos.reporting_period.finalized", subject_type: "PosReportingPeriod", subject_id: period.id).count
  end

  test "stale still-open period finalize stays on enter and reveals no finalized values" do
    period = Pos::OpenReportingPeriod.call(store: @store, register: @register, actor: @actor)
    old_version = period.lock_version
    PosReportingPeriod.where(id: period.id).update_all("lock_version = lock_version + 1")

    post pos_reporting_period_finalize_path(period), params: {
      expected_lock_version: old_version,
      return_to: "enter",
      register_id: @register.id
    }
    assert_response :unprocessable_content
    assert_match "Open session", response.body
    refute_match(/Z report/i, response.body)
    assert period.reload.open?
    assert_nil period.finalized_transaction_count
  end

  test "finalize while a session is open re-renders enter" do
    post pos_register_enter_path, params: enter_params
    period = PosReportingPeriod.open.find_by!(register: @register)
    post pos_reporting_period_finalize_path(period), params: {
      expected_lock_version: period.lock_version,
      return_to: "enter",
      register_id: @register.id
    }
    assert_response :unprocessable_content
    assert_match "open session", response.body
    assert period.reload.open?
  end

  test "second cashier cannot access another cashier close flow but may finalize z" do
    complete_http_sale
    session_record = PosSession.open.find_by!(register: @register)
    Pos::CloseSession.call(
      session: session_record,
      actor: @actor,
      expected_lock_version: session_record.lock_version,
      closing_count_cents: 0
    )
    period = session_record.reporting_period
    other = pos_transacting_user(store: @store, assigned_by: @actor, username: "other_z")
    delete session_path
    sign_in_as("other_z")

    get pos_session_close_path(session_record)
    assert_response :not_found
    get pos_session_closed_path(session_record)
    assert_response :not_found
    post pos_session_close_path(session_record), params: {
      closing_count: "0.00",
      expected_lock_version: session_record.lock_version
    }
    assert_response :not_found

    get pos_register_enter_path, params: { register_id: @register.id }
    assert_match "Finalize Z", response.body
    post pos_reporting_period_finalize_path(period), params: {
      expected_lock_version: period.lock_version,
      return_to: "enter",
      register_id: @register.id
    }
    assert_redirected_to pos_reporting_period_z_path(period)
    follow_redirect!
    assert_response :success
    assert_match other.display_name, response.body
  end

  test "wrong store cannot access close or z" do
    complete_http_sale
    session_record = PosSession.open.find_by!(register: @register)
    Pos::CloseSession.call(
      session: session_record,
      actor: @actor,
      expected_lock_version: session_record.lock_version,
      closing_count_cents: 0
    )
    period = Pos::FinalizeReportingPeriod.call(
      period: session_record.reporting_period,
      actor: @actor,
      expected_lock_version: session_record.reporting_period.lock_version
    )
    east = Store.create!(
      store_number: 2,
      code: "east",
      name: "East Store",
      timezone: "America/New_York",
      country_code: "US"
    )
    post store_selection_path, params: { store_id: east.id }

    get pos_session_close_path(session_record)
    assert_response :not_found
    get pos_session_closed_path(session_record)
    assert_response :not_found
    get pos_reporting_period_z_path(period)
    assert_response :not_found
  end

  test "finalized z is read-only persisted snapshots" do
    complete_http_sale
    session_record = PosSession.open.find_by!(register: @register)
    Pos::CloseSession.call(
      session: session_record,
      actor: @actor,
      expected_lock_version: session_record.lock_version,
      closing_count_cents: 0
    )
    period = Pos::FinalizeReportingPeriod.call(
      period: session_record.reporting_period,
      actor: @actor,
      expected_lock_version: session_record.reporting_period.lock_version
    )
    get pos_reporting_period_z_path(period)
    assert_response :success
    assert_match period.finalized_transaction_count.to_s, response.body
    assert_match format_money(period.finalized_total_cents), response.body
    assert_match format_money(period.finalized_closing_variance_cents_sum), response.body
    assert_match "Opening floats total", response.body
    assert_no_match "Close session", response.body
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

  def complete_http_sale(opening_float: "0.00")
    post pos_register_enter_path, params: enter_params(opening_float: opening_float)
    transaction = PosTransaction.working.find_by!(register: @register)
    post pos_register_merchandise_path, params: { identifier: @variant.sku, lock_version: transaction.lock_version }
    transaction.reload
    post pos_register_tender_path, params: { amount_presented: "25.00", lock_version: transaction.lock_version }
    transaction.reload
    operation_id = css_select("input[name='completion_operation_id']").first["value"]
    post pos_transaction_complete_path(transaction), params: {
      completion_operation_id: operation_id,
      lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents,
      amount_presented_cents: 2500
    }
    transaction.reload
  end

  def format_money(cents)
    sign = cents.negative? ? "-" : ""
    absolute = cents.abs
    "#{sign}$#{absolute / 100}.#{format('%02d', absolute % 100)}"
  end

  def format_store_zone(time)
    zone = ActiveSupport::TimeZone[@store.timezone] || ActiveSupport::TimeZone["UTC"]
    time.in_time_zone(zone).strftime("%Y-%m-%d %H:%M")
  end
end
