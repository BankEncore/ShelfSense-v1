# frozen_string_literal: true

require "test_helper"

module StoredValue
  class AccountActivityTest < ActiveSupport::TestCase
    setup do
      @bootstrap = bootstrap!
      @store = @bootstrap[:store]
      @actor = @bootstrap[:administrator]
      @customer = Customer.create!(display_name: "Ledger Customer", email: "ledger@example.com")
      @account = StoredValue::OpenAccount.call(account_type: "store_credit", customer: @customer)
    end

    test "paginates entries newest first and includes closed accounts" do
      26.times do |index|
        StoredValue::Post.call(
          operation_type: "issue",
          store: @store,
          performed_by: @actor,
          source_id: @account.id,
          idempotency_key: SecureRandom.uuid_v7,
          entries: [ { account: @account.reload, amount_cents: 1 } ]
        )
      end

      page1 = activity(page: 1)
      assert_equal 25, page1.entries.size
      assert_equal 26, page1.total_count
      assert_equal 2, page1.total_pages

      page2 = activity(page: 2)
      assert_equal 1, page2.entries.size
      assert_equal "issue", page2.entries.first.stored_value_operation.operation_type
    end

    test "orders by operation occurred_at then operation id then entry sequence" do
      first = StoredValue::Post.call(
        operation_type: "issue",
        store: @store,
        performed_by: @actor,
        source_id: @account.id,
        idempotency_key: SecureRandom.uuid_v7,
        occurred_at: Time.utc(2026, 8, 1, 12, 0, 0),
        entries: [ { account: @account.reload, amount_cents: 10 } ]
      )
      second = StoredValue::Post.call(
        operation_type: "issue",
        store: @store,
        performed_by: @actor,
        source_id: @account.id,
        idempotency_key: SecureRandom.uuid_v7,
        occurred_at: Time.utc(2026, 8, 2, 12, 0, 0),
        entries: [ { account: @account.reload, amount_cents: 20 } ]
      )

      result = activity
      assert_equal [ second.id, first.id ], result.entries.map { |entry| entry.stored_value_operation_id }
    end

    test "labels transfer direction, adjustment sign, reversals, and reversed originals" do
      other = Customer.create!(display_name: "Transfer Destination", email: "ledger.dest@example.com")
      destination = StoredValue::OpenAccount.call(account_type: "store_credit", customer: other)
      StoredValue::Post.call(
        operation_type: "issue",
        store: @store,
        performed_by: @actor,
        source_id: @account.id,
        idempotency_key: SecureRandom.uuid_v7,
        entries: [ { account: @account.reload, amount_cents: 400 } ]
      )
      StoredValue::Post.call(
        operation_type: "adjust",
        store: @store,
        performed_by: @actor,
        source_id: @account.id,
        idempotency_key: SecureRandom.uuid_v7,
        entries: [ { account: @account.reload, amount_cents: 50 } ]
      )
      StoredValue::Post.call(
        operation_type: "adjust",
        store: @store,
        performed_by: @actor,
        source_id: @account.id,
        idempotency_key: SecureRandom.uuid_v7,
        entries: [ { account: @account.reload, amount_cents: -25 } ]
      )
      StoredValue::Post.call(
        operation_type: "transfer",
        store: @store,
        performed_by: @actor,
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7,
        entries: [
          { account: @account.reload, amount_cents: -100 },
          { account: destination, amount_cents: 100 }
        ]
      )
      cash_out = StoredValue::Post.call(
        operation_type: "cash_out",
        store: @store,
        performed_by: @actor,
        source_id: @account.id,
        idempotency_key: SecureRandom.uuid_v7,
        entries: [ { account: @account.reload, amount_cents: -40 } ]
      )
      StoredValue::Reverse.call(
        operation: cash_out,
        performed_by: @actor,
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7
      )
      activate = StoredValue::Post.call(
        operation_type: "activate",
        store: @store,
        performed_by: @actor,
        source_id: @account.id,
        idempotency_key: SecureRandom.uuid_v7,
        entries: [ { account: @account.reload, amount_cents: 15 } ]
      )
      StoredValue::Reverse.call(
        operation: activate,
        performed_by: @actor,
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7
      )

      labels = activity.rows.to_h { |row| [ row.operation_label, row.amount_cents ] }
      assert_equal(-100, labels["Transfer out"])
      assert_equal 50, labels["Credit adjustment"]
      assert_equal(-25, labels["Debit adjustment"])
      assert_equal 40, labels["Cash-out reversal"]
      assert_equal(-15, labels["Post-void reversal"])
      assert_equal 15, labels["Activate (reversed)"]
    end

    test "store-scoped viewers see other-store amounts without actor or POS identity" do
      other = Store.create!(
        store_number: 91,
        code: "sv_other",
        name: "East Ledger Store",
        legal_name: "East Ledger LLC",
        timezone: "America/New_York",
        country_code: "US"
      )
      StoredValue::Post.call(
        operation_type: "issue",
        store: @store,
        performed_by: @actor,
        source_id: @account.id,
        idempotency_key: SecureRandom.uuid_v7,
        reason_code: "home_issue",
        reason_name_snapshot: "Home store issue",
        entries: [ { account: @account.reload, amount_cents: 80 } ]
      )
      StoredValue::Post.call(
        operation_type: "issue",
        store: other,
        performed_by: @actor,
        source_id: @account.id,
        idempotency_key: SecureRandom.uuid_v7,
        reason_code: "east_issue",
        reason_name_snapshot: "East store issue",
        entries: [ { account: @account.reload, amount_cents: 45 } ]
      )
      manager = pos_store_manager(store: @store, assigned_by: @actor, username: "sv_activity_mgr")

      scoped = StoredValue::AccountActivity.call(
        account: @account,
        actor: manager,
        permission_key: "stored_value.view_activity"
      )
      by_amount = scoped.rows.index_by(&:amount_cents)
      home = by_amount.fetch(80)
      remote = by_amount.fetch(45)

      assert_equal @store.admin_label, home.store_label
      assert_includes home.actor_reason, @actor.display_name
      refute home.redacted

      assert_equal "Another store", remote.store_label
      assert_nil remote.actor_reason
      assert_nil remote.pos_transaction
      assert remote.redacted
      refute_includes scoped.rows.map(&:actor_reason).compact.join, "East store issue"

      global = activity
      remote_global = global.rows.find { |row| row.amount_cents == 45 }
      assert_equal other.admin_label, remote_global.store_label
      assert_includes remote_global.actor_reason, "East store issue"
      refute remote_global.redacted
    end

    private

    def activity(page: 1, actor: @actor, permission_key: "stored_value.view_activity")
      StoredValue::AccountActivity.call(
        account: @account,
        actor: actor,
        permission_key: permission_key,
        page: page
      )
    end
  end
end
