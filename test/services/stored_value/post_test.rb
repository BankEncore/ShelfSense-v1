# frozen_string_literal: true

require "test_helper"

module StoredValue
  class PostTest < ActiveSupport::TestCase
    setup do
      @bootstrap = bootstrap!
      @store = @bootstrap[:store]
      @actor = @bootstrap[:administrator]
      @customer = Customer.create!(display_name: "Credit Customer", email: "credit@example.com")
      @account = StoredValue::OpenAccount.call(account_type: "store_credit", customer: @customer)
    end

    test "posts a credit, updates projection, and writes audit and outbox in the same transaction" do
      operation = post_credit(500)

      assert_equal "issue", operation.operation_type
      assert_equal 500, @account.reload.balance_cents
      entry = operation.stored_value_entries.sole
      assert_equal 500, entry.amount_cents
      assert_equal 500, entry.balance_after_cents
      assert_equal 0, entry.entry_sequence
      assert AuditEvent.exists?(action: "stored_value.post", outcome: "succeeded", subject_id: operation.id)
      assert OutboxMessage.exists?(event_type: "stored_value.issued", aggregate_id: operation.id)
      assert_nil StoredValueOperation.column_names.find { |name| name.end_with?("_source_id") || name == "source_type" }
      assert_not StoredValueOperation.column_names.include?("reversed_by_id")
    end

    test "rejects generic balance assignment" do
      error = assert_raises(StoredValue::Error) { @account.update!(balance_cents: 99) }
      assert_match(/balance_cents cannot be assigned/, error.message)
      assert_equal 0, @account.reload.balance_cents
    end

    test "rejects negative balances and records a failed audit outside the rolled-back mutation" do
      post_credit(100)
      before_entries = StoredValueEntry.count
      before_ops = StoredValueOperation.count

      error = assert_raises(StoredValue::Error) { post_debit(200) }
      assert_match(/negative/, error.message)
      assert_equal 100, @account.reload.balance_cents
      assert_equal before_entries, StoredValueEntry.count
      assert_equal before_ops, StoredValueOperation.count
      assert AuditEvent.exists?(action: "stored_value.post", outcome: "failed")
      assert_equal 1, OutboxMessage.where(event_type: "stored_value.issued").count
    end

    test "idempotent retry returns the same operation" do
      key = SecureRandom.uuid_v7
      source = SecureRandom.uuid_v7
      first = post_credit(250, key: key, source: source)
      second = post_credit(250, key: key, source: source)

      assert_equal first.id, second.id
      assert_equal 1, StoredValueOperation.count
      assert_equal 250, @account.reload.balance_cents
    end

    test "payload mismatch is an error" do
      key = SecureRandom.uuid_v7
      source = SecureRandom.uuid_v7
      post_credit(250, key: key, source: source)

      assert_raises(Idempotency::OperationService::PayloadMismatchError) do
        post_credit(400, key: key, source: source)
      end
    end

    test "locks accounts in UUID order for a transfer that nets to zero" do
      other = Customer.create!(display_name: "Other", email: "other@example.com")
      destination = StoredValue::OpenAccount.call(account_type: "store_credit", customer: other)
      post_credit(300)

      ordered = [ @account, destination ].sort_by(&:id)
      operation = StoredValue::Post.call(
        operation_type: "transfer",
        store: @store,
        performed_by: @actor,
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7,
        entries: [
          { account: ordered.last, amount_cents: 125 },
          { account: ordered.first, amount_cents: -125 }
        ]
      )

      assert_equal 2, operation.stored_value_entries.count
      assert_equal 0, operation.stored_value_entries.sum(:amount_cents)
      assert_equal "stored_value.transferred", OutboxMessage.order(:created_at).last.event_type
    end

    test "database rejects a reversed_by_id column and uniqueness of reversal_of_id" do
      assert_not StoredValueAccount.column_names.include?("reversed_by_id")
      first = post_credit(50)
      StoredValue::Reverse.call(
        operation: first,
        performed_by: @actor,
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7
      )

      assert_raises(StoredValue::Error) do
        StoredValue::Reverse.call(
          operation: first,
          performed_by: @actor,
          source_id: SecureRandom.uuid_v7,
          idempotency_key: SecureRandom.uuid_v7
        )
      end
    end

    test "reverse restores the projection through compensating entries" do
      original = post_credit(80)
      reversal = StoredValue::Reverse.call(
        operation: original,
        performed_by: @actor,
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7
      )

      assert_equal "reverse", reversal.operation_type
      assert_equal original.id, reversal.reversal_of_id
      assert_equal original.id, reversal.reversal_of.id
      assert_equal reversal.id, original.reload.reversed_by.id
      assert_equal 0, @account.reload.balance_cents
      assert_equal(-80, reversal.stored_value_entries.sole.amount_cents)
    end

    test "verify projection reports drift without repairing" do
      post_credit(40)
      StoredValueAccount.where(id: @account.id).update_all(balance_cents: 7)

      drifts = StoredValue::VerifyProjection.call
      drift = drifts.find { |item| item.account.id == @account.id }

      assert_equal 7, drift.projected_cents
      assert_equal 40, drift.ledger_cents
      assert_equal 7, @account.reload.balance_cents
    end

    test "seeded phase 10 permissions grant store managers but not associates the exceptional keys" do
      Authorization::PermissionCatalog.seed!(granted_by: @actor)
      manager = Role.find_by!(key: "store_manager")
      associate = Role.find_by!(key: "associate")
      admin = Role.find_by!(key: "system_administrator")

      assert manager.permissions.exists?(key: "stored_value.adjust")
      assert manager.permissions.exists?(key: "gift_cards.cash_out")
      assert_not manager.permissions.exists?(key: "gift_cards.manage_programs")
      assert_not manager.permissions.exists?(key: "stored_value.manage_adjustment_reasons")
      assert_not associate.permissions.exists?(key: "stored_value.adjust")
      assert admin.permissions.exists?(key: "gift_cards.manage_programs")
      assert_not Permission.exists?(key: "gift_cards.reveal_number")
    end

    test "currency is snapshotted from system settings and is not caller-selectable" do
      assert_equal SystemSettings.current.base_currency_code, @account.currency_code
      error = assert_raises(ActiveRecord::RecordInvalid) { @account.update!(currency_code: "EUR") }
      assert_match(/cannot change/, error.message)
    end

    test "gift-card accounts cannot have a customer_id" do
      card_account = StoredValue::OpenAccount.call(account_type: "gift_card")
      assert_nil card_account.customer_id
      invalid = StoredValueAccount.new(
        account_type: "gift_card",
        customer: @customer,
        currency_code: "USD",
        opened_at: Time.current
      )
      assert_not invalid.valid?
    end

    private

    def post_credit(amount_cents, key: SecureRandom.uuid_v7, source: SecureRandom.uuid_v7)
      StoredValue::Post.call(
        operation_type: "issue",
        store: @store,
        performed_by: @actor,
        source_id: source,
        idempotency_key: key,
        entries: [ { account: @account, amount_cents: amount_cents } ]
      )
    end

    def post_debit(amount_cents)
      StoredValue::Post.call(
        operation_type: "redeem",
        store: @store,
        performed_by: @actor,
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7,
        entries: [ { account: @account, amount_cents: -amount_cents } ]
      )
    end
  end
end
