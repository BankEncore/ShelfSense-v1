# frozen_string_literal: true

require "test_helper"

class PosRegisterStateResolverTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    @front = Register.create!(store: @store, register_number: 1, name: "Front")
    @back = Register.create!(store: @store, register_number: 2, name: "Back")
  end

  test "no inputs resolves to selector" do
    result = resolve
    assert_equal "selector", result.kind
    assert_nil result.register
    assert_nil result.gate
    assert_equal "selector", result.reason
  end

  test "explicit requested register is closed without a period" do
    result = resolve(requested_register: @front)
    assert_equal "closed", result.kind
    assert_equal @front.id, result.register.id
    assert_equal "requested", result.reason
    assert result.gate.opening_new_period?
  end

  test "explicit occupied register plus sole owned session elsewhere does not substitute" do
    pos_open_context(store: @store, actor: @actor, register: @back)
    other = pos_transacting_user(store: @store, assigned_by: @actor, username: "occ_other")
    pos_open_context(store: @store, actor: other, register: @front)
    owned = PosSession.open.where(cashier_user: @actor).includes(:register).to_a

    result = resolve(requested_register: @front, owned_open_sessions: owned)
    assert_equal "occupied", result.kind
    assert_equal @front.id, result.register.id
    assert_equal other.id, result.gate.occupier.id
    assert_equal 1, result.owned_sessions.size
    assert_equal @back.id, result.owned_sessions.first.register_id
  end

  test "explicit closed register plus bound owned session elsewhere uses the request" do
    context = pos_open_context(store: @store, actor: @actor, register: @back)
    owned = [ context[:session] ]

    result = resolve(
      requested_register: @front,
      bound_register_id: @back.id,
      owned_open_sessions: owned
    )
    assert_equal "closed", result.kind
    assert_equal @front.id, result.register.id
    assert_equal "requested", result.reason
  end

  test "stale binding plus sole owned session uses the owned session" do
    context = pos_open_context(store: @store, actor: @actor, register: @front)
    missing_id = SecureRandom.uuid_v7

    result = resolve(bound_register_id: missing_id, owned_open_sessions: [ context[:session] ])
    assert_equal "own_session", result.kind
    assert_equal @front.id, result.register.id
    assert_equal "sole_owned", result.reason
  end

  test "valid preference plus sole owned session uses custody" do
    context = pos_open_context(store: @store, actor: @actor, register: @front)

    result = resolve(preferred_register: @back, owned_open_sessions: [ context[:session] ])
    assert_equal "own_session", result.kind
    assert_equal @front.id, result.register.id
    assert_equal "sole_owned", result.reason
  end

  test "multiple owned sessions plus valid preference stay on selector" do
    first = pos_open_context(store: @store, actor: @actor, register: @front)
    second = pos_open_context(store: @store, actor: @actor, register: @back)
    owned = [ first[:session], second[:session] ]

    result = resolve(preferred_register: @front, owned_open_sessions: owned)
    assert_equal "selector", result.kind
    assert_nil result.register
    assert_equal "multiple_owned", result.reason
    assert_equal [ @front.id, @back.id ], result.owned_sessions.map(&:register_id)
  end

  test "multiple owned sessions plus explicit request uses the request" do
    first = pos_open_context(store: @store, actor: @actor, register: @front)
    second = pos_open_context(store: @store, actor: @actor, register: @back)
    owned = [ first[:session], second[:session] ]

    result = resolve(requested_register: @back, preferred_register: @front, owned_open_sessions: owned)
    assert_equal "own_session", result.kind
    assert_equal @back.id, result.register.id
    assert_equal "requested", result.reason
  end

  test "bound session plus different preference uses the bound session" do
    first = pos_open_context(store: @store, actor: @actor, register: @front)
    second = pos_open_context(store: @store, actor: @actor, register: @back)
    owned = [ first[:session], second[:session] ]

    result = resolve(
      preferred_register: @front,
      bound_register_id: @back.id,
      owned_open_sessions: owned
    )
    assert_equal "own_session", result.kind
    assert_equal @back.id, result.register.id
    assert_equal "bound", result.reason
  end

  test "leftover period without a session is between_sessions" do
    Pos::OpenReportingPeriod.call(store: @store, register: @front, actor: @actor)
    travel_to Time.current + 1.day do
      result = resolve(requested_register: @front)
      assert_equal "between_sessions", result.kind
      assert result.gate.leftover_period?
      assert result.gate.can_finalize_period?
    end
  end

  test "open period without a session is between_sessions" do
    Pos::OpenReportingPeriod.call(store: @store, register: @front, actor: @actor)
    result = resolve(requested_register: @front)
    assert_equal "between_sessions", result.kind
    refute result.gate.leftover_period?
  end

  test "stale inactive preferred register is ignored" do
    @front.update_columns(active: false, updated_at: Time.current)
    result = resolve(preferred_register: @front.reload)
    assert_equal "selector", result.kind
    assert_nil result.register
  end

  test "cross-store register is ignored" do
    other_store = Store.create!(
      store_number: "9",
      code: "other",
      name: "Other Store",
      legal_name: "Other Books LLC",
      timezone: "America/New_York",
      country_code: "US"
    )
    foreign = Register.create!(store: other_store, register_number: 1, name: "Foreign")
    result = resolve(requested_register: foreign, preferred_register: foreign)
    assert_equal "selector", result.kind
    assert_nil result.register
  end

  test "owned sessions are listed by register number" do
    second = pos_open_context(store: @store, actor: @actor, register: @back)
    first = pos_open_context(store: @store, actor: @actor, register: @front)
    result = resolve(owned_open_sessions: [ second[:session], first[:session] ])
    assert_equal [ @front.id, @back.id ], result.owned_sessions.map(&:register_id)
  end

  private

  def resolve(requested_register: nil, preferred_register: nil, bound_register_id: nil, owned_open_sessions: [])
    Pos::RegisterStateResolver.call(
      store: @store,
      actor: @actor,
      requested_register: requested_register,
      preferred_register: preferred_register,
      bound_register_id: bound_register_id,
      owned_open_sessions: owned_open_sessions
    )
  end
end
