# frozen_string_literal: true

require "test_helper"

module Cash
  class SafeReconAndDepositTest < ActiveSupport::TestCase
    setup do
      @bootstrap = bootstrap!
      @store = @bootstrap[:store]
      @actor = @bootstrap[:administrator]
      Cash::ActivityReasons.seed!
      @safe = Cash::Locations.safe_for!(@store)
      @context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 10_000)
      @session = @context[:session]
    end

    test "zero-variance safe recon accepts the count without a reconciliation row" do
      expected = @safe.reload.expected_balance_cents
      start_count = Cash::SnapshotCount.start!(location: @safe, purpose: "safe_reconciliation")
      accepted = Cash::ReconcileSafe.call(
        store: @store,
        actor: @actor,
        start_count: start_count,
        count_cents: expected,
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7
      )

      assert_equal "accepted", accepted.status
      assert_equal expected, accepted.total_cents
      assert_equal 0, CashReconciliation.where(cash_location: @safe).count
      report = Cash::StoreDayReport.for(store: @store, business_date: accepted.business_date)
      assert report.safe_reconciled?
      assert_includes report.status_labels, "safe reconciled"

      error = assert_raises(Cash::Error) do
        Cash::ReconcileSafe.call(
          store: @store,
          actor: @actor,
          start_count: start_count,
          count_cents: expected,
          source_id: SecureRandom.uuid_v7,
          idempotency_key: SecureRandom.uuid_v7
        )
      end
      assert_equal Cash::SnapshotCount::ALREADY_ACCEPTED, error.message
      assert_equal 1, CashCount.where(superseded_count_id: start_count.id).count
      assert_equal 1, AuditEvent.where(action: "cash.reconcile_safe", outcome: "succeeded", subject_id: accepted.id).count
    end

    test "accept! refuses a snapshot that is not the discarded start row" do
      start_count = Cash::SnapshotCount.start!(location: @safe.reload, purpose: "safe_reconciliation")
      accepted = Cash::SnapshotCount.accept!(count: start_count, total_cents: start_count.expected_cents_snapshot)

      error = assert_raises(Cash::Error) do
        Cash::SnapshotCount.accept!(count: accepted, total_cents: accepted.total_cents)
      end
      assert_equal Cash::SnapshotCount::NOT_DISCARDED, error.message
    end

    test "nonzero safe over posts a reconciliation and rebases expected cash" do
      expected = @safe.reload.expected_balance_cents
      start_count = Cash::SnapshotCount.start!(location: @safe, purpose: "safe_reconciliation")
      accepted = Cash::ReconcileSafe.call(
        store: @store,
        actor: @actor,
        start_count: start_count,
        count_cents: expected + 250,
        reason_code: "over_count",
        notes: "Found an extra bundle",
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7
      )

      recon = CashReconciliation.find_by!(cash_count: accepted)
      assert_equal "over", recon.direction
      assert_equal 250, recon.variance_cents
      assert_equal expected + 250, @safe.reload.expected_balance_cents
      assert_equal Cash::SafeTotals.for(@safe).from_entries_cents, @safe.expected_balance_cents
    end

    test "activity during a safe count makes the count stale" do
      start_count = Cash::SnapshotCount.start!(location: @safe, purpose: "safe_reconciliation")
      Cash::Drop.call(
        session: @session,
        actor: @actor,
        amount_cents: 500,
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7
      )

      error = assert_raises(Cash::Error) do
        Cash::ReconcileSafe.call(
          store: @store,
          actor: @actor,
          start_count: start_count,
          count_cents: start_count.expected_cents_snapshot,
          source_id: SecureRandom.uuid_v7,
          idempotency_key: SecureRandom.uuid_v7
        )
      end
      assert_equal Cash::SnapshotCount::STALE, error.message
    end

    test "deposit moves safe cash to deposit in transit" do
      safe_before = @safe.reload.expected_balance_cents
      dit = Cash::Locations.deposit_in_transit_for!(@store)
      start_count = Cash::SnapshotCount.start!(location: @safe, purpose: "deposit")
      deposit = Cash::PrepareDeposit.call(
        store: @store,
        actor: @actor,
        start_count: start_count,
        amount_cents: 2_000,
        bag_reference: "BAG-1",
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7
      )

      assert_equal 2_000, deposit.total_cents
      assert_equal 1, deposit.deposit_number
      assert_equal "BAG-1", deposit.bag_reference
      assert_equal "deposit", deposit.cash_operation.cash_transfer.transfer_type
      assert_equal safe_before - 2_000, @safe.reload.expected_balance_cents
      assert_equal 2_000, dit.reload.expected_balance_cents
      assert OutboxMessage.exists?(event_type: "cash.deposit_prepared")
    end

    test "reverse of a deposit restores the safe without fabricating a deposit row" do
      start_count = Cash::SnapshotCount.start!(location: @safe.reload, purpose: "deposit")
      deposit = Cash::PrepareDeposit.call(
        store: @store,
        actor: @actor,
        start_count: start_count,
        amount_cents: 1_500,
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7
      )
      safe_before = @safe.reload.expected_balance_cents
      dit_before = Cash::Locations.deposit_in_transit_for!(@store).expected_balance_cents
      reverse = Cash::Reverse.call(
        operation: deposit.cash_operation,
        actor: @actor,
        reason_code: "reverse",
        notes: "Bag never left the store",
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7
      )

      assert_equal "reverse", reverse.operation_type
      assert_nil reverse.cash_deposit
      assert_equal 1_500, CashDeposit.find(deposit.id).total_cents
      assert deposit.cash_operation.reload.reversed?
      assert_equal safe_before + 1_500, @safe.reload.expected_balance_cents
      assert_equal dit_before - 1_500, Cash::Locations.deposit_in_transit_for!(@store).expected_balance_cents

      error = assert_raises(Cash::Error) do
        Cash::Reverse.call(
          operation: deposit.cash_operation,
          actor: @actor,
          reason_code: "reverse",
          notes: "again",
          source_id: SecureRandom.uuid_v7,
          idempotency_key: SecureRandom.uuid_v7
        )
      end
      assert_match(/already been reversed/, error.message)
    end

    test "store-day lists that date's deposits and treats DIT as cumulative" do
      Cash::PaidIn.call(
        session: @session,
        actor: @actor,
        amount_cents: 300,
        reason_code: "paid_in_found",
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7
      )
      first = Cash::SnapshotCount.start!(location: @safe.reload, purpose: "deposit")
      Cash::PrepareDeposit.call(
        store: @store,
        actor: @actor,
        start_count: first,
        amount_cents: 1_000,
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7
      )
      second = Cash::SnapshotCount.start!(location: @safe.reload, purpose: "deposit")
      Cash::PrepareDeposit.call(
        store: @store,
        actor: @actor,
        start_count: second,
        amount_cents: 400,
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7
      )
      report = Cash::StoreDayReport.for(
        store: @store,
        business_date: BusinessDate.for_store(@store)
      )

      assert_equal 2, report.deposits.size
      assert_equal [ 1, 2 ], report.deposits.map { |row| row.deposit.deposit_number }
      assert_equal 1_400, report.dit_balance_cents
      assert report.deposit_prepared?
      assert_includes report.status_labels, "incomplete"
      assert_equal 300, report.paid_ins.sum(&:amount_cents)
    end
  end
end
