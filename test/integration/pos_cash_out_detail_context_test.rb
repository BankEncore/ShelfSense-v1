# frozen_string_literal: true

require "test_helper"

class PosCashOutDetailContextTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    GiftCards::Programs.seed!
    StoredValue::AdjustmentReasons.seed!
    Cash::ActivityReasons.seed!
    @program = GiftCardProgram.find_by!(code: "generated")
    @register_b = Register.create!(store: @store, register_number: 41, name: "Foreign")
    @clerk = pos_store_manager(store: @store, assigned_by: @actor, username: "cashout_clerk")
    @foreign = pos_open_context(store: @store, actor: @clerk, register: @register_b, opening_float_cents: 10_000)
    @cash_out = cash_out_on!(@foreign[:session], @clerk, 500)
    @register_a = Register.create!(store: @store, register_number: 42, name: "Manager")
    @owned = pos_open_context(store: @store, actor: @actor, register: @register_a, opening_float_cents: 10_000)
    sign_in_as("admin")
  end

  test "till activity detail link preserves inspected register and session" do
    get pos_till_activity_path(register_id: @register_b.id, session_id: @foreign[:session].id)
    assert_response :success
    assert_select "a[href=?]",
                  pos_cash_out_path(@cash_out, register_id: @register_b.id, session_id: @foreign[:session].id)
  end

  test "manager viewing another cashier cash-out does not offer reverse into owned till" do
    get pos_cash_out_path(@cash_out, register_id: @register_b.id, session_id: @foreign[:session].id)
    assert_response :success
    assert_match @register_b.admin_label, response.body
    assert_match @clerk.display_name, response.body
    assert_match @register_a.admin_label, response.body
    assert_match(/Reversal is available only while you hold the original open Register session/i, response.body)
    assert_select "form[action='#{reverse_pos_cash_out_path(@cash_out)}']", count: 0

    post reverse_pos_cash_out_path(@cash_out), params: {
      register_id: @register_b.id,
      session_id: @foreign[:session].id,
      physical_cash_returned: "1",
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    }
    assert_redirected_to pos_cash_out_path(@cash_out, register_id: @cash_out.register_id, session_id: @cash_out.pos_session_id)
    refute @cash_out.reload.reversed?
    assert_equal @owned[:session].id, cashier_open_for(@actor).id
  end

  test "historical cash-out while manager owns another till does not offer reverse" do
    pos_close_session!(session: @foreign[:session], actor: @clerk, closing_count_cents: 9_500)
    get pos_cash_out_path(@cash_out, register_id: @register_b.id, session_id: @foreign[:session].id)
    assert_response :success
    assert_match(/Closed/, response.body)
    assert_select "form[action='#{reverse_pos_cash_out_path(@cash_out)}']", count: 0
  end

  test "mismatched register or session params are not found" do
    get pos_cash_out_path(@cash_out, register_id: @register_a.id, session_id: @foreign[:session].id)
    assert_redirected_to pos_path

    get pos_cash_out_path(@cash_out, register_id: @register_b.id, session_id: @owned[:session].id)
    assert_redirected_to pos_path
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end

  def cash_out_on!(session, actor, amount_cents)
    card = GiftCards::ProvisionInstrument.call(program: @program, store: @store)
    GiftCards::Fund.call(gift_card: card, amount_cents: amount_cents, store: @store, performed_by: @actor)
    GiftCards::CashOut.call(
      gift_card: card,
      session: session,
      actor: actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    )
  end

  def cashier_open_for(user)
    PosSession.open.find_by!(store: @store, cashier_user: user)
  end
end
