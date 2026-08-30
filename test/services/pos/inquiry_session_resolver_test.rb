# frozen_string_literal: true

require "test_helper"

class PosInquirySessionResolverTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    @register = Register.create!(store: @store, register_number: 7, name: "Resolver")
  end

  test "own session returns the owned session" do
    context = pos_open_context(store: @store, actor: @actor, register: @register, opening_float_cents: 1_000)
    state = state_for(register: @register, owned: [ context[:session] ])

    result = resolve(state:)
    assert_equal :ok, result.status
    assert_equal context[:session].id, result.session.id
  end

  test "occupied without sessions.view is denied" do
    manager = pos_store_manager(store: @store, assigned_by: @actor, username: "occ_mgr")
    context = pos_open_context(store: @store, actor: manager, register: @register, opening_float_cents: 1_000)
    clerk = pos_transacting_user(store: @store, assigned_by: @actor, username: "occ_clerk")
    state = occupied_state(register: @register, session: context[:session])

    result = resolve(state:, actor: clerk)
    assert_equal :denied, result.status
    assert_equal "sessions_view_required", result.denied_reason
  end

  test "occupied with sessions.view returns the occupying session" do
    clerk = pos_transacting_user(store: @store, assigned_by: @actor, username: "occ_owner")
    context = pos_open_context(store: @store, actor: clerk, register: @register, opening_float_cents: 1_000)
    state = occupied_state(register: @register, session: context[:session])

    result = resolve(state:, actor: @actor)
    assert_equal :ok, result.status
    assert_equal context[:session].id, result.session.id
  end

  test "between sessions prefers the most recently closed session on the open period" do
    first = pos_open_context(store: @store, actor: @actor, register: @register, opening_float_cents: 500)
    pos_close_session!(session: first[:session], actor: @actor, closing_count_cents: 500)
    second = Pos::OpenSession.call(
      store: @store,
      register: @register,
      actor: @actor,
      reporting_period: first[:period],
      opening_float_cents: 500
    )
    pos_close_session!(session: second, actor: @actor, closing_count_cents: 500)

    gate = Struct.new(:period, :session, :can_finalize_period?).new(first[:period], nil, false)
    state = Struct.new(:kind, :register, :gate, :owned_sessions).new("between_sessions", @register, gate, [])

    result = resolve(state:)
    assert_equal :ok, result.status
    assert_equal second.id, result.session.id
  end

  test "closed register returns a chooser of viewable recent sessions" do
    context = pos_open_context(store: @store, actor: @actor, register: @register, opening_float_cents: 500)
    pos_close_session!(session: context[:session], actor: @actor, closing_count_cents: 500)
    Pos::FinalizeReportingPeriod.call(
      period: context[:period].reload,
      actor: @actor,
      expected_lock_version: context[:period].lock_version
    )

    gate = Struct.new(:period, :session).new(nil, nil)
    state = Struct.new(:kind, :register, :gate, :owned_sessions).new("closed", @register, gate, [])

    result = resolve(state:)
    assert_equal :chooser, result.status
    assert_includes result.candidate_sessions.map(&:id), context[:session].id
  end

  test "selector without register is denied" do
    state = Struct.new(:kind, :register, :gate, :owned_sessions).new("selector", nil, nil, [])
    result = resolve(state:)
    assert_equal :denied, result.status
    assert_equal "register_required", result.denied_reason
  end

  test "explicit session_id must match store register and authorization" do
    context = pos_open_context(store: @store, actor: @actor, register: @register, opening_float_cents: 500)
    other_register = Register.create!(store: @store, register_number: 8, name: "Other")
    state = state_for(register: @register, owned: [ context[:session] ])

    ok = resolve(state:, session_id: context[:session].id, register_id_param: @register.id)
    assert_equal :ok, ok.status

    mismatch = resolve(state:, session_id: context[:session].id, register_id_param: other_register.id)
    assert_equal :denied, mismatch.status
    assert_equal "not_found", mismatch.denied_reason

    clerk = pos_transacting_user(store: @store, assigned_by: @actor, username: "deny_hist")
    foreign_state = state_for(register: other_register, owned: [])
    denied = Pos::InquirySessionResolver.call(
      store: @store,
      actor: clerk,
      state: foreign_state,
      session_id: context[:session].id
    )
    assert_equal :denied, denied.status
  end

  private

  def resolve(state:, actor: @actor, session_id: nil, register_id_param: nil)
    Pos::InquirySessionResolver.call(
      store: @store,
      actor: actor,
      state: state,
      session_id: session_id,
      register_id_param: register_id_param
    )
  end

  def state_for(register:, owned:)
    Pos::RegisterStateResolver.call(
      store: @store,
      actor: @actor,
      requested_register: register,
      preferred_register: nil,
      bound_register_id: nil,
      owned_open_sessions: owned
    )
  end

  def occupied_state(register:, session:)
    gate = Struct.new(:session, :period).new(session, session.reporting_period)
    Struct.new(:kind, :register, :gate, :owned_sessions).new("occupied", register, gate, [])
  end
end
