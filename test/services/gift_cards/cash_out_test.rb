# frozen_string_literal: true

require "test_helper"

class GiftCardsCashOutTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    @approver = create_store_manager("cash_out_approver")
    GiftCards::Programs.seed!
    StoredValue::AdjustmentReasons.seed!
    @program = GiftCardProgram.find_by!(code: "generated")
    @context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 10_000)
    @session = @context[:session]
  end

  test "cashes out the full eligible balance and reduces expected cash" do
    card = funded_card(500)
    before = Pos::SessionTotals.for(@session).expected_cash_cents

    cash_out = GiftCards::CashOut.call(
      gift_card: card,
      session: @session,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    )

    assert_equal 500, cash_out.amount_cents
    assert_equal @session.register_id, cash_out.register_id
    assert_equal 0, card.stored_value_account.reload.balance_cents
    assert card.reload.closed?
    assert_equal "cash_out", cash_out.stored_value_operation.operation_type
    assert_equal before - 500, Pos::SessionTotals.for(@session.reload).expected_cash_cents
    assert OutboxMessage.exists?(event_type: "stored_value.cash_out_completed")
    assert PosControlledAction.exists?(action_type: "gift_card_cash_out", gift_card_cash_out_id: cash_out.id)
    groups = Pos::OperatorReport.session(totals: Pos::SessionTotals.for(@session), session: @session, kind: :x)
    stored_value = groups.find { |group| group.title == "Stored value" }
    cash = groups.find { |group| group.title == "Cash custody" }
    assert_equal 500, stored_value.rows.find { |row| row.label == "Gift-card cash-outs" && row.format != :count }.cents
    assert_equal 500, cash.rows.find { |row| row.label == "Gift-card cash-outs" }.cents
  end

  test "associates cannot cash out" do
    card = funded_card(500)
    associate = User.create!(
      username: "cash_out_assoc",
      display_name: "Associate",
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    RoleAssignment.create!(
      user: associate,
      role: Role.find_by!(key: "associate"),
      store: @store,
      assigned_by: @actor,
      effective_at: Time.current
    )

    error = assert_raises(GiftCards::Error) do
      GiftCards::CashOut.call(
        gift_card: card,
        session: @session,
        actor: associate,
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7
      )
    end
    assert_match(/not authorized/, error.message)
    assert_equal 500, card.stored_value_account.reload.balance_cents
  end

  test "required_on_request_when_eligible does not pay out without confirmation" do
    @program.update!(cash_out_policy: "required_on_request_when_eligible")
    card = funded_card(400)
    error = assert_raises(GiftCards::Error) do
      GiftCards::CashOut.call(
        gift_card: card,
        session: @session,
        actor: @actor,
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7
      )
    end
    assert_match(/customer requested/, error.message)

    cash_out = GiftCards::CashOut.call(
      gift_card: card,
      session: @session,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      customer_requested: true
    )
    assert_equal 400, cash_out.amount_cents
  end

  test "cash_out_approval_required uses PosControlledAction second user" do
    @program.update!(cash_out_approval_required: true)
    card = funded_card(250)
    error = assert_raises(GiftCards::Error) do
      GiftCards::CashOut.call(
        gift_card: card,
        session: @session,
        actor: @actor,
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7
      )
    end
    assert_match(/approver/, error.message)

    cash_out = GiftCards::CashOut.call(
      gift_card: card,
      session: @session,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      approver_username: @approver.username,
      approver_password: "correct-horse-battery"
    )
    action = cash_out.pos_controlled_action
    assert_equal "approval_required", action.policy_result
    assert_equal @approver.id, action.approved_by_user_id
  end

  test "reversal requires physical cash confirmation and credits the reversing session" do
    card = funded_card(500)
    original = GiftCards::CashOut.call(
      gift_card: card,
      session: @session,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    )
    after_cash_out = Pos::SessionTotals.for(@session.reload).expected_cash_cents

    error = assert_raises(GiftCards::Error) do
      GiftCards::ReverseCashOut.call(
        cash_out: original,
        session: @session,
        actor: @actor,
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7,
        physical_cash_returned: false
      )
    end
    assert_match(/physically returned/, error.message)

    reversal = GiftCards::ReverseCashOut.call(
      cash_out: original,
      session: @session,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      physical_cash_returned: true
    )
    assert reversal.reversal?
    assert_equal original.id, reversal.reversal_of_id
    assert_equal 500, card.stored_value_account.reload.balance_cents
    assert card.reload.active?
    assert_equal after_cash_out + 500, Pos::SessionTotals.for(@session.reload).expected_cash_cents
  end

  test "closed session expected cash stays on the snapshot after a later cash-out reverse" do
    card = funded_card(500)
    GiftCards::CashOut.call(
      gift_card: card,
      session: @session,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    )
    closed = Pos::CloseSession.call(
      session: @session,
      actor: @actor,
      expected_lock_version: @session.lock_version,
      closing_count_cents: 9_500
    )
    snapshot = closed.closing_expected_cash_cents
    assert_equal 9_500, snapshot
    assert_equal snapshot, Pos::SessionTotals.for(closed).expected_cash_cents
  end

  test "print recovery returns the number with a reason and does not put it in audit" do
    card = funded_card(200)
    number = GiftCards::PrintRecovery.call(
      gift_card: card,
      actor: @actor,
      store: @store,
      reason: "printer jammed after first print"
    )
    assert_equal card.number, number
    event = AuditEvent.where(action: "gift_cards.print_recovery").order(:created_at).last
    assert_equal "succeeded", event.outcome
    refute event.after_values.values.any? { |value| value.to_s.include?(card.number) }
    assert_equal card.number_last_four, event.after_values["number_last_four"]
  end

  private

  def funded_card(amount_cents)
    card = GiftCards::ProvisionInstrument.call(program: @program, store: @store)
    GiftCards::Fund.call(gift_card: card, amount_cents: amount_cents, store: @store, performed_by: @actor)
    card
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
