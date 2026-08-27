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

    test "identical complete payload replays" do
      key = SecureRandom.uuid_v7
      source = SecureRandom.uuid_v7
      attrs = complete_session_post_attrs(key: key, source: source, notes: "  envelope  ")
      first = Cash::Post.call(**attrs)
      second = Cash::Post.call(**complete_session_post_attrs(key: key, source: source, notes: "envelope"))

      assert_equal first.id, second.id
      assert_equal "envelope", first.notes
      assert_equal 1, CashOperation.where(id: first.id).count
    end

    test "changed reason is a payload mismatch" do
      key = SecureRandom.uuid_v7
      source = SecureRandom.uuid_v7
      Cash::Post.call(**complete_session_post_attrs(key: key, source: source, reason_code: "paid_in_found"))

      assert_raises(Idempotency::OperationService::PayloadMismatchError) do
        Cash::Post.call(**complete_session_post_attrs(key: key, source: source, reason_code: "paid_in_other", notes: "other"))
      end
    end

    test "changed notes are a payload mismatch" do
      key = SecureRandom.uuid_v7
      source = SecureRandom.uuid_v7
      Cash::Post.call(**complete_session_post_attrs(key: key, source: source, notes: "first"))

      assert_raises(Idempotency::OperationService::PayloadMismatchError) do
        Cash::Post.call(**complete_session_post_attrs(key: key, source: source, notes: "second"))
      end
    end

    test "changed actor is a payload mismatch" do
      key = SecureRandom.uuid_v7
      source = SecureRandom.uuid_v7
      Cash::Post.call(**complete_session_post_attrs(key: key, source: source))
      other = cash_distinct_approver(store: @store, assigned_by: @actor)

      assert_raises(Idempotency::OperationService::PayloadMismatchError) do
        Cash::Post.call(**complete_session_post_attrs(key: key, source: source, performed_by: other))
      end
    end

    test "changed store is a payload mismatch" do
      key = SecureRandom.uuid_v7
      source = SecureRandom.uuid_v7
      post_safe(250, key: key, source: source)
      other = other_store

      assert_raises(Idempotency::OperationService::PayloadMismatchError) do
        Cash::Post.call(
          operation_type: "initialize_safe",
          store: other,
          performed_by: @actor,
          source_id: source,
          idempotency_key: key,
          entries: [ { cash_location: Cash::Locations.safe_for!(other), amount_cents: 250 } ]
        )
      end
    end

    test "changed outbox event type is a payload mismatch" do
      key = SecureRandom.uuid_v7
      source = SecureRandom.uuid_v7
      post_safe(250, key: key, source: source)

      assert_raises(Idempotency::OperationService::PayloadMismatchError) do
        post_safe(250, key: key, source: source, outbox_event_type: "cash.deposit_prepared")
      end
    end

    test "changed business date is a payload mismatch" do
      key = SecureRandom.uuid_v7
      source = SecureRandom.uuid_v7
      Cash::Post.call(**complete_session_post_attrs(key: key, source: source, business_date: Date.current))

      assert_raises(Idempotency::OperationService::PayloadMismatchError) do
        Cash::Post.call(**complete_session_post_attrs(key: key, source: source, business_date: Date.current - 1))
      end
    end

    test "changed occurred_at is a payload mismatch when supplied" do
      key = SecureRandom.uuid_v7
      source = SecureRandom.uuid_v7
      at = Time.zone.parse("2026-08-26 12:00:00 UTC")
      Cash::Post.call(**complete_session_post_attrs(key: key, source: source, occurred_at: at))

      assert_raises(Idempotency::OperationService::PayloadMismatchError) do
        Cash::Post.call(**complete_session_post_attrs(key: key, source: source, occurred_at: at + 1.second))
      end
    end

    test "rejects a location that belongs to another store" do
      other_safe = Cash::Locations.safe_for!(other_store)
      before = other_safe.expected_balance_cents

      error = assert_raises(Cash::Error) do
        post_safe(25, cash_location: other_safe)
      end
      assert_match(/does not belong to this store/, error.message)
      assert_equal before, other_safe.reload.expected_balance_cents
      assert_equal 0, CashEntry.where(cash_location: other_safe).count
    end

    test "rejects a session that belongs to another store" do
      context = pos_open_context(store: other_store, actor: @actor, opening_float_cents: 0)

      error = assert_raises(Cash::Error) do
        Cash::Post.call(
          operation_type: "paid_in",
          store: @store,
          performed_by: @actor,
          pos_session: context[:session],
          source_id: SecureRandom.uuid_v7,
          idempotency_key: SecureRandom.uuid_v7,
          entries: [ { pos_session: context[:session], amount_cents: 100, balance_after_cents: 100 } ]
        )
      end
      assert_match(/does not belong to this store/, error.message)
    end

    test "rejects a transfer that credits another store" do
      other_safe = Cash::Locations.safe_for!(other_store)
      home_before = @safe.expected_balance_cents
      other_before = other_safe.expected_balance_cents

      error = assert_raises(Cash::Error) do
        Cash::Post.call(
          operation_type: "transfer",
          store: @store,
          performed_by: @actor,
          source_id: SecureRandom.uuid_v7,
          idempotency_key: SecureRandom.uuid_v7,
          entries: [
            { cash_location: @safe, amount_cents: -100 },
            { cash_location: other_safe, amount_cents: 100 }
          ]
        )
      end
      assert_match(/does not belong to this store/, error.message)
      assert_equal home_before, @safe.reload.expected_balance_cents
      assert_equal other_before, other_safe.reload.expected_balance_cents
    end

    private

    def post_safe(amount_cents, key: SecureRandom.uuid_v7, source: SecureRandom.uuid_v7, **attrs)
      Cash::Post.call(
        operation_type: "initialize_safe",
        store: attrs.fetch(:store, @store),
        performed_by: attrs.fetch(:performed_by, @actor),
        source_id: source,
        idempotency_key: key,
        entries: attrs[:entries] || [ { cash_location: attrs[:cash_location] || @safe, amount_cents: amount_cents } ],
        **attrs.except(:store, :performed_by, :entries, :cash_location)
      )
    end

    def complete_session_post_attrs(key:, source:, **overrides)
      Cash::ActivityReasons.seed!
      session = overrides.delete(:session) ||
                (@complete_post_session ||= pos_open_context(store: @store, actor: @actor, opening_float_cents: 0)[:session])
      {
        operation_type: "paid_in",
        store: @store,
        performed_by: @actor,
        pos_session: session,
        source_id: source,
        idempotency_key: key,
        business_date: Date.current,
        occurred_at: Time.zone.parse("2026-08-26 15:00:00 UTC"),
        reason_code: "paid_in_found",
        reason_name_snapshot: "Found cash",
        notes: "envelope",
        entries: [ { pos_session: session, amount_cents: 100, balance_after_cents: 100 } ]
      }.merge(overrides)
    end

    def other_store
      @other_store ||= Store.create!(
        store_number: 88,
        code: "east-cash",
        name: "East",
        legal_name: "East LLC",
        timezone: "America/New_York",
        country_code: "US"
      )
    end
  end
end
