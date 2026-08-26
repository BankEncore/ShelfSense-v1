# frozen_string_literal: true

require "test_helper"

module StoredValue
  class AdjustTest < ActiveSupport::TestCase
    setup do
      @bootstrap = bootstrap!
      @store = @bootstrap[:store]
      @actor = @bootstrap[:administrator]
      @approver = create_store_manager("sv_approver")
      @customer = Customer.create!(display_name: "Credit Customer", email: "sv.adjust@example.com")
      @account = StoredValue::OpenAccount.call(account_type: "store_credit", customer: @customer)
      @goodwill = StoredValueAdjustmentReason.find_by!(code: "goodwill")
      @debit_reason = StoredValueAdjustmentReason.find_by!(code: "correction_debit")
    end

    test "credits store credit through an adjust operation and never edits the balance field" do
      adjustment = credit!(500)

      assert_equal "credit", adjustment.adjustment_direction
      assert_equal 500, adjustment.amount_cents
      assert_equal "goodwill", adjustment.reason_code
      assert_equal 500, @account.reload.balance_cents
      assert_equal "adjust", adjustment.stored_value_operation.operation_type
      assert_equal 500, adjustment.stored_value_operation.stored_value_entries.sole.amount_cents
      assert OutboxMessage.exists?(event_type: "stored_value.adjusted", aggregate_id: adjustment.stored_value_operation_id)
      assert_not StoredValueAdjustmentReason.exists?(code: "opening_balance")
    end

    test "small credits do not require a second user" do
      adjustment = credit!(100)

      assert_nil adjustment.approved_by_id
    end

    test "credits at the organization threshold require a second user" do
      error = assert_raises(StoredValue::Error) { credit!(5000, approved_by: nil) }
      assert_match(/second-user/, error.message)

      adjustment = credit!(5000, approved_by: @approver)
      assert_equal @approver.id, adjustment.approved_by_id
    end

    test "debits always require a second user and notes when the reason requires them" do
      credit!(200)
      error = assert_raises(StoredValue::Error) do
        debit!(50, approved_by: nil, notes: "correction")
      end
      assert_match(/second-user/, error.message)

      error = assert_raises(StoredValue::Error) { debit!(50, approved_by: @approver, notes: "") }
      assert_match(/notes are required/, error.message)

      adjustment = debit!(50, approved_by: @approver, notes: "fix over-credit")
      assert_equal 150, @account.reload.balance_cents
      assert_equal @approver.id, adjustment.approved_by_id
    end

    test "performer cannot self-approve" do
      error = assert_raises(StoredValue::Error) { credit!(5000, approved_by: @actor) }
      assert_match(/approver cannot be the performer/, error.message)
    end

    test "inactive customers cannot receive new credit" do
      @customer.update!(active: false)
      error = assert_raises(StoredValue::Error) { credit!(100) }
      assert_match(/inactive customers cannot receive new credit/, error.message)
    end

    test "adjusts an active gift card and blocks replaced cards" do
      GiftCards::Programs.seed!
      program = GiftCardProgram.find_by!(code: "generated")
      card = GiftCards::ProvisionInstrument.call(program: program, store: @store)
      GiftCards::Fund.call(gift_card: card, amount_cents: 400, store: @store, performed_by: @actor)

      adjustment = StoredValue::Adjust.call(
        account: card.stored_value_account,
        direction: "credit",
        amount_cents: 100,
        reason: @goodwill,
        store: @store,
        performed_by: @actor,
        source_id: card.stored_value_account_id,
        idempotency_key: SecureRandom.uuid_v7
      )
      assert_equal 500, card.stored_value_account.reload.balance_cents
      assert_equal "adjust", adjustment.stored_value_operation.operation_type

      GiftCards::Replace.call(
        gift_card: card,
        performed_by: @actor,
        store: @store,
        source_id: card.id,
        idempotency_key: SecureRandom.uuid_v7,
        reason_code: "lost",
        reason_name_snapshot: "Lost card"
      )
      error = assert_raises(StoredValue::Error) do
        StoredValue::Adjust.call(
          account: card.stored_value_account.reload,
          direction: "credit",
          amount_cents: 10,
          reason: @goodwill,
          store: @store,
          performed_by: @actor,
          source_id: card.stored_value_account_id,
          idempotency_key: SecureRandom.uuid_v7
        )
      end
      assert card.reload.replaced?
      assert_match(/closed|replaced/, error.message)
    end

    test "idempotent retry returns the same adjustment" do
      key = SecureRandom.uuid_v7
      first = credit!(250, key: key)
      second = credit!(250, key: key)

      assert_equal first.id, second.id
      assert_equal 1, StoredValueAdjustment.count
      assert_equal 250, @account.reload.balance_cents
    end

    test "accounts are created only for active canonical customers" do
      merged_source = Customer.create!(display_name: "Alias", email: "sv.alias@example.com")
      Customers::MergeCustomers.call(
        source: merged_source,
        survivor: @customer,
        actor: @actor,
        reason: "same person",
        idempotency_key: SecureRandom.uuid_v7,
        store: @store
      )
      error = assert_raises(StoredValue::Error) do
        StoredValue::OpenAccount.call(account_type: "trade_credit", customer: merged_source.reload)
      end
      assert_match(/canonical/, error.message)
    end

    private

    def credit!(amount_cents, approved_by: nil, key: SecureRandom.uuid_v7)
      StoredValue::Adjust.call(
        account: @account,
        direction: "credit",
        amount_cents: amount_cents,
        reason: @goodwill,
        store: @store,
        performed_by: @actor,
        approved_by: approved_by,
        source_id: @account.id,
        idempotency_key: key
      )
    end

    def debit!(amount_cents, approved_by:, notes:)
      StoredValue::Adjust.call(
        account: @account,
        direction: "debit",
        amount_cents: amount_cents,
        reason: @debit_reason,
        store: @store,
        performed_by: @actor,
        approved_by: approved_by,
        source_id: @account.id,
        idempotency_key: SecureRandom.uuid_v7,
        internal_notes: notes
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
