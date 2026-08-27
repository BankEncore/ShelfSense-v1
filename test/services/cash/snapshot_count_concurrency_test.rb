# frozen_string_literal: true

require "test_helper"

module Cash
  class SnapshotCountConcurrencyTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    setup do
      @bootstrap = bootstrap!
      @store = @bootstrap[:store]
      @actor = @bootstrap[:administrator]
      Cash::ActivityReasons.seed!
      @safe = Cash::Locations.safe_for!(@store)
      @start_count = Cash::SnapshotCount.start!(location: @safe, purpose: "safe_reconciliation")
    end

    teardown do
      conn = ActiveRecord::Base.connection
      tables = conn.tables - %w[schema_migrations ar_internal_metadata]
      conn.disable_referential_integrity do
        tables.each { |table| conn.execute("TRUNCATE TABLE #{conn.quote_table_name(table)} CASCADE") }
      end
    end

    test "concurrent zero-variance accepts consume the snapshot once" do
      start_id = @start_count.id
      counted = @start_count.expected_cents_snapshot
      store_id = @store.id
      actor_id = @actor.id
      results = Array.new(2)
      errors = Array.new(2)
      threads = 2.times.map do |i|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            results[i] = Cash::ReconcileSafe.call(
              store: Store.find(store_id),
              actor: User.find(actor_id),
              start_count: CashCount.find(start_id),
              count_cents: counted,
              source_id: SecureRandom.uuid_v7,
              idempotency_key: SecureRandom.uuid_v7
            )
          rescue StandardError => e
            errors[i] = e
          end
        end
      end
      threads.each { |thread| assert thread.join(20), "thread did not finish" }

      successes = results.compact
      failures = errors.compact
      assert_equal 1, successes.size, "expected one accept, got #{successes.size}; errors=#{failures.map(&:message)}"
      assert_equal 1, failures.size
      assert_equal Cash::SnapshotCount::ALREADY_ACCEPTED, failures.first.message
      assert_equal 1, CashCount.where(superseded_count_id: start_id).count
      assert_equal 1, AuditEvent.where(action: "cash.reconcile_safe", outcome: "succeeded", subject_id: successes.first.id).count
    end
  end
end
