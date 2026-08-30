# frozen_string_literal: true

require "test_helper"

module Pos
  class ReportingPeriodFinalizeBlockersTest < ActiveSupport::TestCase
    setup do
      @bootstrap = bootstrap!
      @store = @bootstrap[:store]
      @actor = @bootstrap[:administrator]
      @context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 0)
    end

    test "open session blocks finalize" do
      result = Pos::ReportingPeriodFinalizeBlockers.call(period: @context[:period])
      assert_not result.ready?
      assert result.blockers.any? { |b| b.include?("open session") }
    end

    test "closed session with snapshots is ready" do
      pos_close_session!(
        session: @context[:session],
        actor: @actor,
        closing_count_cents: 0
      )
      result = Pos::ReportingPeriodFinalizeBlockers.call(period: @context[:period].reload)
      assert result.ready?
      assert_empty result.blockers
    end
  end
end
