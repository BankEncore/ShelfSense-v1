# frozen_string_literal: true

require "test_helper"

module Cash
  class PostTest < ActiveSupport::TestCase
    setup do
      @bootstrap = bootstrap!
      @store = @bootstrap[:store]
      @actor = @bootstrap[:administrator]
      @safe = Cash::Locations.safe_for!(@store)
    end

    test "posts a credit, updates projection, and writes audit and outbox in the same transaction" do
      operation = post_safe(500)

      assert_equal "initialize_safe", operation.operation_type
      assert_equal 100_000 + 500, @safe.reload.expected_balance_cents
      entry = operation.cash_entries.sole
      assert_equal 500, entry.amount_cents
      assert_equal 100_500, entry.balance_after_cents
      assert_equal 0, entry.entry_sequence
      assert AuditEvent.exists?(action: "cash.post", outcome: "succeeded", subject_id: operation.id)
      assert OutboxMessage.exists?(event_type: "cash.safe_initialized", aggregate_id: operation.id)
      assert_not CashOperation.column_names.include?("reversed_by_id")
    end

    test "rejects generic balance assignment" do
      error = assert_raises(Cash::Error) { @safe.update!(expected_balance_cents: 99) }
      assert_match(/expected_balance_cents cannot be assigned/, error.message)
      assert_equal 100_000, @safe.reload.expected_balance_cents
    end

    test "rejects negative balances and records a failed audit outside the rolled-back mutation" do
      before_entries = CashEntry.count
      before_ops = CashOperation.where(operation_type: "transfer").count
      before_balance = @safe.expected_balance_cents

      error = assert_raises(Cash::Error) { post_safe(-(before_balance + 1)) }
      assert_match(/negative/, error.message)
      assert_equal before_balance, @safe.reload.expected_balance_cents
      assert_equal before_entries, CashEntry.count
      assert_equal before_ops, CashOperation.where(operation_type: "transfer").count
      assert AuditEvent.exists?(action: "cash.post", outcome: "failed")
    end

    test "idempotent retry returns the same operation" do
      key = SecureRandom.uuid_v7
      source = SecureRandom.uuid_v7
      first = post_safe(250, key: key, source: source)
      second = post_safe(250, key: key, source: source)

      assert_equal first.id, second.id
      assert_equal 250, CashEntry.where(cash_operation: first).sum(:amount_cents)
    end

    test "payload mismatch is an error" do
      key = SecureRandom.uuid_v7
      source = SecureRandom.uuid_v7
      post_safe(250, key: key, source: source)

      assert_raises(Idempotency::OperationService::PayloadMismatchError) do
        post_safe(400, key: key, source: source)
      end
    end

    test "transfer entries must net to zero" do
      context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 0)
      error = assert_raises(Cash::Error) do
        Cash::Post.call(
          operation_type: "transfer",
          store: @store,
          performed_by: @actor,
          source_id: SecureRandom.uuid_v7,
          idempotency_key: SecureRandom.uuid_v7,
          entries: [
            { cash_location: @safe, amount_cents: -100 },
            { pos_session: context[:session], amount_cents: 50, balance_after_cents: 50 }
          ]
        )
      end
      assert_match(/net to zero/, error.message)
    end

    test "approver must differ from the performer" do
      error = assert_raises(Cash::Error) do
        Cash::Post.call(
          operation_type: "initialize_safe",
          store: @store,
          performed_by: @actor,
          approved_by: @actor,
          source_id: SecureRandom.uuid_v7,
          idempotency_key: SecureRandom.uuid_v7,
          entries: [ { cash_location: @safe, amount_cents: 1 } ]
        )
      end
      assert_match(/differ/, error.message)
    end

    private

    def post_safe(amount_cents, key: SecureRandom.uuid_v7, source: SecureRandom.uuid_v7)
      Cash::Post.call(
        operation_type: "initialize_safe",
        store: @store,
        performed_by: @actor,
        source_id: source,
        idempotency_key: key,
        entries: [ { cash_location: @safe, amount_cents: amount_cents } ]
      )
    end
  end
end
