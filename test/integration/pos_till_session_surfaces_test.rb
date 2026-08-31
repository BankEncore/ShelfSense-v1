# frozen_string_literal: true

require "test_helper"

class PosTillSessionSurfacesTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    Cash::ActivityReasons.seed!
    @register = Register.create!(store: @store, register_number: 21, name: "Till")
    @context = pos_open_context(store: @store, actor: @actor, register: @register, opening_float_cents: 10_000)
    sign_in_as("admin")
  end

  test "owner can view till activity and session details for the current session" do
    Cash::PaidIn.call(
      session: @context[:session],
      actor: @actor,
      amount_cents: 250,
      reason_code: "paid_in_found",
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    )

    get pos_till_activity_path(register_id: @register.id)
    assert_response :success
    assert_select ".pos-register-shell"
    assert_match "Till Activity", response.body
    assert_match "Paid in", response.body
    assert_match(/Expected cash/, response.body)
    assert_match(/\+\$2\.50/, response.body)

    get pos_session_details_path(@context[:session], register_id: @register.id)
    assert_response :success
    assert_match "Session Details", response.body
    assert_match @actor.display_name, response.body
    assert_match(/Expected cash/, response.body)
  end

  test "associate without expected-cash permission sees op effects but not expected cash" do
    clerk = pos_transacting_user(store: @store, assigned_by: @actor, username: "till_blind")
    register = Register.create!(store: @store, register_number: 22, name: "Blind")
    context = pos_open_context(store: @store, actor: clerk, register: register, opening_float_cents: 5_000)
    Cash::Drop.call(
      session: context[:session],
      actor: clerk,
      amount_cents: 300,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    )
    delete session_path
    sign_in_as("till_blind")

    get pos_till_activity_path(register_id: register.id)
    assert_response :success
    assert_match "Cash drop", response.body
    assert_match(/-\$3\.00/, response.body)
    refute_match(/Expected cash/i, response.body)

    get pos_session_details_path(context[:session], register_id: register.id)
    assert_response :success
    refute_match(/Expected cash/i, response.body)
  end

  test "other cashier requires sessions.view and historical own session is allowed" do
    clerk = pos_transacting_user(store: @store, assigned_by: @actor, username: "till_peer")
    delete session_path
    sign_in_as("till_peer")

    get pos_till_activity_path(register_id: @register.id)
    assert_redirected_to pos_path

    get pos_session_details_path(@context[:session], register_id: @register.id)
    assert_redirected_to pos_path

    own_register = Register.create!(store: @store, register_number: 23, name: "Peer own")
    own = pos_open_context(store: @store, actor: clerk, register: own_register, opening_float_cents: 1_000)
    pos_close_session!(session: own[:session], actor: clerk, closing_count_cents: 1_000)

    get pos_session_details_path(own[:session], register_id: own_register.id)
    assert_response :success
  end

  test "cross-store and mismatched register session ids are not found" do
    other_register = Register.create!(store: @store, register_number: 24, name: "Mismatch")

    get pos_till_activity_path(register_id: @register.id, session_id: SecureRandom.uuid_v7)
    assert_redirected_to pos_path

    get pos_till_activity_path(register_id: other_register.id, session_id: @context[:session].id)
    assert_redirected_to pos_path

    get pos_session_details_path(@context[:session], register_id: other_register.id)
    assert_response :not_found
  end

  test "selector entry redirects and closed register shows a chooser" do
    clerk = pos_transacting_user(store: @store, assigned_by: @actor, username: "till_selector")
    delete session_path
    sign_in_as("till_selector")

    get pos_till_activity_path
    assert_redirected_to pos_path

    delete session_path
    sign_in_as("admin")
    pos_close_session!(session: @context[:session], actor: @actor, closing_count_cents: 10_000)
    Pos::FinalizeReportingPeriod.call(
      period: @context[:period].reload,
      actor: @actor,
      expected_lock_version: @context[:period].lock_version
    )

    get pos_till_activity_path(register_id: @register.id)
    assert_response :success
    assert_match(/Select a historical session/, response.body)
    assert_match "View till", response.body
  end

  test "active sessions is shell-wrapped without expected cash or assisted close" do
    get pos_active_sessions_path(register_id: @register.id)
    assert_response :success
    assert_select ".pos-register-shell"
    assert_match "Active Sessions", response.body
    assert_select "main.pos-history a", text: "Session details"
    assert_select "main.pos-history a", text: "Till Activity"
    assert_select "main.pos-history", text: /Expected cash/, count: 0
    assert_select "main.pos-history", text: /Assisted Close/, count: 0
  end

  test "GET till and session surfaces do not mutate counts or create records" do
    before_ops = CashOperation.count
    before_sessions = PosSession.count
    working = Pos::StartTransaction.call(session: @context[:session], actor: @actor)

    get pos_till_activity_path(register_id: @register.id)
    assert_response :success
    get pos_session_details_path(@context[:session], register_id: @register.id)
    assert_response :success

    assert_equal before_ops, CashOperation.count
    assert_equal before_sessions, PosSession.count
    assert working.reload.working?
  end

  test "cash forms render in the register shell and redirect without custody" do
    get new_pos_cash_paid_in_path
    assert_response :success
    assert_select ".pos-register-shell"
    assert_match "Paid-in", response.body
    assert_match "Return to Register", response.body

    clerk = pos_transacting_user(store: @store, assigned_by: @actor, username: "no_custody")
    delete session_path
    sign_in_as("no_custody")
    get new_pos_cash_drop_path
    assert_redirected_to pos_path
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end
end
