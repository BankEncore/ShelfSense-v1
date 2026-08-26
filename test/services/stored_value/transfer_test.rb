# frozen_string_literal: true

require "test_helper"

module StoredValue
  class TransferTest < ActiveSupport::TestCase
    setup do
      @bootstrap = bootstrap!
      @store = @bootstrap[:store]
      @actor = @bootstrap[:administrator]
      @approver = create_store_manager("sv_xfer_approver")
      @source_customer = Customer.create!(display_name: "Source Credit", email: "sv.src@example.com")
      @dest_customer = Customer.create!(display_name: "Dest Credit", email: "sv.dst@example.com")
      @from = StoredValue::OpenAccount.call(account_type: "store_credit", customer: @source_customer)
      @to = StoredValue::OpenAccount.call(account_type: "store_credit", customer: @dest_customer)
      fund!(@from, 400)
    end

    test "administrative partial transfer leaves source open and nets to zero" do
      transfer = transfer!(amount_cents: 150, transfer_type: "administrative")

      assert_equal 250, @from.reload.balance_cents
      assert_equal 150, @to.reload.balance_cents
      assert @from.active?
      assert_equal 0, transfer.stored_value_operation.stored_value_entries.sum(:amount_cents)
      assert OutboxMessage.exists?(event_type: "stored_value.transferred", aggregate_id: transfer.stored_value_operation_id)
    end

    test "consolidation moves the full balance and closes source" do
      transfer = transfer!(amount_cents: 400, transfer_type: "account_consolidation")

      assert_equal 0, @from.reload.balance_cents
      assert @from.closed?
      assert_equal 400, @to.reload.balance_cents
      assert_equal "account_consolidation", transfer.transfer_type
    end

    test "cross-type conversion is prohibited" do
      trade = StoredValue::OpenAccount.call(account_type: "trade_credit", customer: @dest_customer)
      error = assert_raises(StoredValue::Error) do
        transfer!(amount_cents: 50, transfer_type: "administrative", to_account: trade)
      end
      assert_match(/cross-type conversion is prohibited/, error.message)
    end

    test "second user is required and cannot be the performer" do
      error = assert_raises(StoredValue::Error) do
        transfer!(amount_cents: 50, transfer_type: "administrative", approved_by: nil)
      end
      assert_match(/second-user/, error.message)

      error = assert_raises(StoredValue::Error) do
        transfer!(amount_cents: 50, transfer_type: "administrative", approved_by: @actor)
      end
      assert_match(/approver cannot be the performer/, error.message)
    end

    test "customer merge does not require stored_value.transfer approval" do
      transfer = StoredValue::Transfer.call(
        from_account: @from,
        to_account: @to,
        amount_cents: 400,
        transfer_type: "customer_merge",
        performed_by: @actor,
        store: @store,
        source_id: @source_customer.id,
        idempotency_key: SecureRandom.uuid_v7
      )

      assert_nil transfer.approved_by_id
      assert @from.reload.closed?
      assert_equal 400, @to.reload.balance_cents
    end

    private

    def fund!(account, amount_cents)
      StoredValue::Post.call(
        operation_type: "issue",
        store: @store,
        performed_by: @actor,
        source_id: account.id,
        idempotency_key: SecureRandom.uuid_v7,
        entries: [ { account: account, amount_cents: amount_cents } ]
      )
    end

    def transfer!(amount_cents:, transfer_type:, to_account: @to, approved_by: @approver)
      StoredValue::Transfer.call(
        from_account: @from,
        to_account: to_account,
        amount_cents: amount_cents,
        transfer_type: transfer_type,
        performed_by: @actor,
        approved_by: approved_by,
        store: @store,
        source_id: @from.id,
        idempotency_key: SecureRandom.uuid_v7,
        reason_code: "test_transfer",
        reason_name_snapshot: "Test transfer"
      )
    end

    def create_store_manager(username)
      user = User.create!(
        username: username,
        display_name: username.titleize,
        password: "correct-horse-battery",
        password_confirmation: "correct-horse-battery"
      )
      RoleAssignment.create!(
        user: user,
        role: Role.find_by!(key: "store_manager"),
        store: @store,
        assigned_by: @actor,
        effective_at: Time.current
      )
      user
    end
  end
end
