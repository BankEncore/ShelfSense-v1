# frozen_string_literal: true

require "test_helper"

class PosRegisterShellContextTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    @register = Register.create!(store: @store, register_number: 3, name: "Shell")
  end

  test "own session returns to the owned workspace" do
    context = pos_open_context(store: @store, actor: @actor, register: @register)
    state = state_for(register: @register, owned: [ context[:session] ])
    result = Pos::RegisterShellContext.call(
      store: @store,
      actor: @actor,
      state: state,
      surface: :transaction_history,
      can_view_expected_cash: true
    )

    assert_equal :transaction_history, result.surface
    assert_equal "own_session", result.kind
    assert_equal :inquiry, result.menu_surface
    assert_equal true, result.can_view_expected_cash
    assert_equal pos_register_workspace_path(register_id: @register.id), result.return_path
    assert_equal "Return to Register", result.return_label
    assert_equal context[:session], result.session
  end

  test "closed and between sessions return to pos with register_id" do
    %w[closed between_sessions].each do |kind|
      state = fake_state(kind: kind, register: @register)
      result = call_context(state:)
      assert_equal pos_path(register_id: @register.id), result.return_path, kind
      assert_equal "Close", result.return_label, kind
    end
  end

  test "occupied returns to occupied register state never workspace" do
    state = fake_state(kind: "occupied", register: @register)
    result = call_context(state:)
    assert_equal pos_path(register_id: @register.id), result.return_path
    refute_match %r{/pos/register}, result.return_path
  end

  test "selector returns to pos without inventing a register" do
    state = fake_state(kind: "selector", register: nil)
    result = call_context(state:)
    assert_equal pos_path, result.return_path
    assert_equal "Close", result.return_label
  end

  test "rejects unknown surfaces" do
    state = fake_state(kind: "selector", register: nil)
    assert_raises(ArgumentError) do
      call_context(state:, surface: :not_a_surface)
    end
  end

  test "expected cash flag is boolean and does not invent visibility" do
    state = fake_state(kind: "selector", register: nil)
    refute call_context(state:, can_view_expected_cash: false).can_view_expected_cash
    assert call_context(state:, can_view_expected_cash: true).can_view_expected_cash
  end

  private

  def call_context(state:, surface: :transaction_history, can_view_expected_cash: false)
    Pos::RegisterShellContext.call(
      store: @store,
      actor: @actor,
      state: state,
      surface: surface,
      can_view_expected_cash: can_view_expected_cash
    )
  end

  def fake_state(kind:, register:)
    Struct.new(:kind, :register, :gate, :owned_sessions).new(kind, register, nil, [])
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
end
