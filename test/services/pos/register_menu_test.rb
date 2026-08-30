# frozen_string_literal: true

require "test_helper"

class PosRegisterMenuTest < ActiveSupport::TestCase
  ALL_PERMISSIONS = %w[pos.sessions.view gift_cards.cash_out cash.paid_in cash.paid_out cash.move].freeze

  test "selector includes transactions session z switch and return" do
    keys = keys_for(kind: "selector", surface: :state_landing, permissions: ALL_PERMISSIONS)
    assert_equal %i[transactions session_z_reports active_sessions switch_register return_to_shelfsense], keys
    refute_includes keys, :x_report
    refute_includes keys, :close_session
    refute_includes keys, :drop
  end

  test "selector without sessions.view omits active sessions" do
    keys = keys_for(kind: "selector", surface: :state_landing, permissions: [])
    refute_includes keys, :active_sessions
    assert_includes keys, :session_z_reports
  end

  test "closed state landing includes open register and omits x report" do
    keys = keys_for(kind: "closed", surface: :state_landing, permissions: ALL_PERMISSIONS)
    assert_includes keys, :open_register
    refute_includes keys, :open_session
    refute_includes keys, :x_report
    refute_includes keys, :close_session
    refute_includes keys, :drop
  end

  test "between sessions includes open session and finalize when the gate allows" do
    gate = Struct.new(:can_finalize_period?).new(true)
    keys = keys_for(kind: "between_sessions", surface: :state_landing, permissions: ALL_PERMISSIONS, gate: gate)
    assert_includes keys, :open_session
    assert_includes keys, :finalize_z
    refute_includes keys, :open_register
    refute_includes keys, :x_report
  end

  test "between sessions omits finalize when the gate cannot" do
    gate = Struct.new(:can_finalize_period?).new(false)
    keys = keys_for(kind: "between_sessions", surface: :state_landing, permissions: ALL_PERMISSIONS, gate: gate)
    refute_includes keys, :finalize_z
  end

  test "workspace own session emits till x and close session without inspecting a basket" do
    keys = keys_for(kind: "own_session", surface: :workspace, permissions: ALL_PERMISSIONS)
    assert_includes keys, :transactions
    assert_includes keys, :x_report
    assert_includes keys, :drop
    assert_includes keys, :paid_in
    assert_includes keys, :close_session
    refute_includes keys, :open_register
  end

  test "workspace till items are permission-filtered and drop is always present" do
    keys = keys_for(kind: "own_session", surface: :workspace, permissions: [])
    assert_includes keys, :drop
    refute_includes keys, :paid_in
    refute_includes keys, :paid_out
    refute_includes keys, :replenish
    refute_includes keys, :gift_card_cash_out
  end

  test "occupied includes x and session z only with sessions.view and a session" do
    gate = Struct.new(:session).new(Object.new)
    with_view = keys_for(kind: "occupied", surface: :state_landing, permissions: [ "pos.sessions.view" ], gate: gate)
    assert_includes with_view, :x_report
    assert_includes with_view, :session_z_reports
    assert_includes with_view, :active_sessions
    refute_includes with_view, :close_session
    refute_includes with_view, :drop

    without_view = keys_for(kind: "occupied", surface: :state_landing, permissions: [], gate: gate)
    refute_includes without_view, :x_report
    refute_includes without_view, :session_z_reports
    refute_includes without_view, :active_sessions
  end

  test "occupied without a session omits x report" do
    gate = Struct.new(:session).new(nil)
    keys = keys_for(kind: "occupied", surface: :state_landing, permissions: [ "pos.sessions.view" ], gate: gate)
    refute_includes keys, :x_report
  end

  test "switch register suppresses switch till x close and in-page mutations" do
    keys = keys_for(kind: "own_session", surface: :switch_register, permissions: ALL_PERMISSIONS)
    assert_equal %i[transactions session_z_reports active_sessions return_to_shelfsense], keys
    refute_includes keys, :switch_register
    refute_includes keys, :x_report
    refute_includes keys, :drop
    refute_includes keys, :close_session
    refute_includes keys, :open_register
    refute_includes keys, :open_session
    refute_includes keys, :finalize_z
  end

  test "switch register occupied keeps permissioned session z and active sessions" do
    gate = Struct.new(:session).new(Object.new)
    keys = keys_for(kind: "occupied", surface: :switch_register, permissions: [ "pos.sessions.view" ], gate: gate)
    assert_includes keys, :transactions
    assert_includes keys, :session_z_reports
    assert_includes keys, :active_sessions
    assert_includes keys, :return_to_shelfsense
    refute_includes keys, :x_report
    refute_includes keys, :switch_register
  end

  test "never emits reverse cash" do
    %w[selector closed between_sessions own_session occupied].each do |kind|
      %i[state_landing workspace switch_register inquiry].each do |surface|
        keys = keys_for(kind:, surface:, permissions: ALL_PERMISSIONS)
        refute_includes keys, :reverse_cash
      end
    end
  end

  test "inquiry suppresses open finalize and close proxies" do
    gate = Struct.new(:can_finalize_period?).new(true)
    closed = keys_for(kind: "closed", surface: :inquiry, permissions: ALL_PERMISSIONS)
    assert_includes closed, :transactions
    refute_includes closed, :open_register
    refute_includes closed, :close_session

    between = keys_for(kind: "between_sessions", surface: :inquiry, permissions: ALL_PERMISSIONS, gate: gate)
    refute_includes between, :open_session
    refute_includes between, :finalize_z

    own = keys_for(kind: "own_session", surface: :inquiry, permissions: ALL_PERMISSIONS)
    assert_includes own, :transactions
    assert_includes own, :drop
    refute_includes own, :close_session
  end

  test "empty groups are omitted" do
    result = Pos::RegisterMenu.call(kind: "closed", surface: :state_landing, permissions: [])
    refute_includes result.groups.map(&:key), :till
  end

  private

  def keys_for(kind:, surface:, permissions:, gate: nil)
    Pos::RegisterMenu.call(kind:, surface:, permissions:, gate:).groups.flat_map(&:item_keys)
  end
end
