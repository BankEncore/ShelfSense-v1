# frozen_string_literal: true

require "test_helper"

module Cash
  class NonSaleActivityTest < ActiveSupport::TestCase
    setup do
      @bootstrap = bootstrap!
      @store = @bootstrap[:store]
      @actor = @bootstrap[:administrator]
      Cash::ActivityReasons.seed!
      @context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 10_000)
      @session = @context[:session]
    end

    test "paid-in increases available cash and is not a tender" do
      before = Pos::SessionTotals.for(@session).available_cash_cents
      paid_in = Cash::PaidIn.call(
        session: @session,
        actor: @actor,
        amount_cents: 500,
        reason_code: "paid_in_found",
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7
      )

      assert_equal 500, paid_in.amount_cents
      assert_equal before + 500, Pos::SessionTotals.for(@session.reload).available_cash_cents
      assert_equal 0, Pos::SessionTotals.for(@session).cash_payment_cents
      assert_equal "paid_in", paid_in.cash_operation.operation_type
      cash = Pos::OperatorReport.session(
        totals: Pos::SessionTotals.for(@session),
        session: @session,
        kind: :x
      ).find { |group| group.title == "Cash custody" }
      assert_equal 500, cash.rows.find { |row| row.label == "Non-sale cash" }.cents
    end

    test "paid-out below threshold is direct and decreases available cash" do
      before = Pos::SessionTotals.for(@session).available_cash_cents
      paid_out = Cash::PaidOut.call(
        session: @session,
        actor: @actor,
        amount_cents: 400,
        reason_code: "paid_out_supplies",
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7
      )

      assert_equal 400, paid_out.amount_cents
      assert_equal before - 400, Pos::SessionTotals.for(@session.reload).available_cash_cents
      action = paid_out.pos_controlled_action
      assert_equal "direct", action.policy_result
      assert_nil action.approved_by_user_id
    end

    test "material paid-out without approve permission requires a distinct approver" do
      role = Role.create!(key: "payout_only_#{SecureRandom.hex(3)}", name: "Payout only", assignment_scope: "store")
      %w[pos.transact cash.paid_out].each do |key|
        RolePermission.create!(role: role, permission: Permission.find_by!(key: key), granted_by: @actor)
      end
      clerk = User.create!(
        username: "payout_clerk",
        display_name: "Payout clerk",
        password: "correct-horse-battery",
        password_confirmation: "correct-horse-battery"
      )
      RoleAssignment.create!(
        user: clerk,
        role: role,
        store: @store,
        assigned_by: @actor,
        effective_at: Time.current
      )
      context = pos_open_context(
        store: @store,
        actor: clerk,
        register: Register.create!(store: @store, register_number: 12, name: "Payout"),
        opening_float_cents: 10_000
      )

      error = assert_raises(Cash::Error) do
        Cash::PaidOut.call(
          session: context[:session],
          actor: clerk,
          amount_cents: 5_000,
          reason_code: "paid_out_supplies",
          source_id: SecureRandom.uuid_v7,
          idempotency_key: SecureRandom.uuid_v7
        )
      end
      assert_match(/approver credentials are required/, error.message)
    end

    test "drop moves session cash to the safe" do
      safe_before = Cash::Locations.safe_for!(@store).expected_balance_cents
      session_before = Pos::SessionTotals.for(@session).available_cash_cents
      transfer = Cash::Drop.call(
        session: @session,
        actor: @actor,
        amount_cents: 2_000,
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7
      )

      assert_equal "drop", transfer.transfer_type
      assert_equal session_before - 2_000, Pos::SessionTotals.for(@session.reload).available_cash_cents
      assert_equal safe_before + 2_000, Cash::Locations.safe_for!(@store).expected_balance_cents
    end

    test "replenish moves safe cash to the session" do
      safe_before = Cash::Locations.safe_for!(@store).expected_balance_cents
      session_before = Pos::SessionTotals.for(@session).available_cash_cents
      transfer = Cash::Replenish.call(
        session: @session,
        actor: @actor,
        amount_cents: 1_500,
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7
      )

      assert_equal "replenishment", transfer.transfer_type
      assert_equal session_before + 1_500, Pos::SessionTotals.for(@session.reload).available_cash_cents
      assert_equal safe_before - 1_500, Cash::Locations.safe_for!(@store).expected_balance_cents
    end

    test "reverse of a paid-in restores available cash without a fabricated source row" do
      paid_in = Cash::PaidIn.call(
        session: @session,
        actor: @actor,
        amount_cents: 700,
        reason_code: "paid_in_found",
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7
      )
      before = Pos::SessionTotals.for(@session.reload).available_cash_cents
      reverse = Cash::Reverse.call(
        operation: paid_in.cash_operation,
        actor: @actor,
        reason_code: "reverse",
        notes: "Entered the wrong amount",
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7
      )

      assert_equal "reverse", reverse.operation_type
      assert_equal paid_in.cash_operation.id, reverse.reversal_of_id
      assert_nil reverse.cash_paid_in
      assert_equal paid_in.amount_cents, CashPaidIn.find(paid_in.id).amount_cents
      assert_equal before - 700, Pos::SessionTotals.for(@session.reload).available_cash_cents
    end

    test "does not reverse session close, over/short, or safe initialization" do
      close = pos_close_session!(session: @session, actor: @actor, closing_count_cents: 10_000)
      close_op = CashTransfer.find_by!(transfer_type: "session_close", source_pos_session: close).cash_operation
      error = assert_raises(Cash::Error) do
        Cash::Reverse.call(
          operation: close_op,
          actor: @actor,
          reason_code: "reverse",
          notes: "no",
          source_id: SecureRandom.uuid_v7,
          idempotency_key: SecureRandom.uuid_v7
        )
      end
      assert_match(/cannot be reversed/, error.message)

      init = CashSafeInitialization.find_by!(cash_location: Cash::Locations.safe_for!(@store))
      error = assert_raises(Cash::Error) do
        Cash::Reverse.call(
          operation: init.cash_operation,
          actor: @actor,
          reason_code: "reverse",
          notes: "no",
          source_id: SecureRandom.uuid_v7,
          idempotency_key: SecureRandom.uuid_v7
        )
      end
      assert_match(/cannot be reversed/, error.message)
    end

    test "reverse of a drop restores session and safe cash without a fabricated transfer" do
      transfer = Cash::Drop.call(
        session: @session,
        actor: @actor,
        amount_cents: 1_200,
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7
      )
      session_before = Pos::SessionTotals.for(@session.reload).available_cash_cents
      safe_before = Cash::Locations.safe_for!(@store).expected_balance_cents
      reverse = Cash::Reverse.call(
        operation: transfer.cash_operation,
        actor: @actor,
        reason_code: "reverse",
        notes: "Dropped the wrong amount",
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7
      )

      assert_equal "reverse", reverse.operation_type
      assert_nil reverse.cash_transfer
      assert_equal "drop", CashTransfer.find(transfer.id).transfer_type
      assert_equal session_before + 1_200, Pos::SessionTotals.for(@session.reload).available_cash_cents
      assert_equal safe_before - 1_200, Cash::Locations.safe_for!(@store).expected_balance_cents
    end

    test "does not reverse the same operation twice" do
      paid_in = Cash::PaidIn.call(
        session: @session,
        actor: @actor,
        amount_cents: 300,
        reason_code: "paid_in_found",
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7
      )
      reverse = Cash::Reverse.call(
        operation: paid_in.cash_operation,
        actor: @actor,
        reason_code: "reverse",
        notes: "first reverse",
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7
      )
      error = assert_raises(Cash::Error) do
        Cash::Reverse.call(
          operation: reverse,
          actor: @actor,
          reason_code: "reverse",
          notes: "second reverse",
          source_id: SecureRandom.uuid_v7,
          idempotency_key: SecureRandom.uuid_v7
        )
      end
      assert_match(/already a reverse/, error.message)

      error = assert_raises(Cash::Error) do
        Cash::Reverse.call(
          operation: paid_in.cash_operation.reload,
          actor: @actor,
          reason_code: "reverse",
          notes: "second reverse",
          source_id: SecureRandom.uuid_v7,
          idempotency_key: SecureRandom.uuid_v7
        )
      end
      assert_match(/already been reversed/, error.message)
    end

    test "associates may drop but cannot paid-in, replenish, or reverse" do
      clerk = pos_transacting_user(store: @store, assigned_by: @actor, username: "drop_clerk")
      context = pos_open_context(
        store: @store,
        actor: clerk,
        register: Register.create!(store: @store, register_number: 14, name: "Clerk"),
        opening_float_cents: 10_000
      )
      session = context[:session]

      Cash::Drop.call(
        session: session,
        actor: clerk,
        amount_cents: 500,
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7
      )

      error = assert_raises(Cash::Error) do
        Cash::PaidIn.call(
          session: session,
          actor: clerk,
          amount_cents: 100,
          reason_code: "paid_in_found",
          source_id: SecureRandom.uuid_v7,
          idempotency_key: SecureRandom.uuid_v7
        )
      end
      assert_match(/not authorized/, error.message)

      error = assert_raises(Cash::Error) do
        Cash::Replenish.call(
          session: session,
          actor: clerk,
          amount_cents: 100,
          source_id: SecureRandom.uuid_v7,
          idempotency_key: SecureRandom.uuid_v7
        )
      end
      assert_match(/not authorized/, error.message)

      drop = CashTransfer.find_by!(transfer_type: "drop", source_pos_session: session)
      error = assert_raises(Cash::Error) do
        Cash::Reverse.call(
          operation: drop.cash_operation,
          actor: clerk,
          reason_code: "reverse",
          notes: "no",
          source_id: SecureRandom.uuid_v7,
          idempotency_key: SecureRandom.uuid_v7
        )
      end
      assert_match(/not authorized/, error.message)
    end

    test "paid-out is refused when available cash is insufficient" do
      empty = pos_open_context(
        store: @store,
        actor: @actor,
        register: Register.create!(store: @store, register_number: 13, name: "Empty"),
        opening_float_cents: 0
      )
      error = assert_raises(Cash::Error) do
        Cash::PaidOut.call(
          session: empty[:session],
          actor: @actor,
          amount_cents: 100,
          reason_code: "paid_out_supplies",
          source_id: SecureRandom.uuid_v7,
          idempotency_key: SecureRandom.uuid_v7
        )
      end
      assert_equal Cash::INSUFFICIENT_AVAILABLE_CASH, error.message
    end
  end
end
