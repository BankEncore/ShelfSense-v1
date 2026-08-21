# frozen_string_literal: true

require "test_helper"

class PosUnlinkedReturnWorkspaceTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    @tax = tax_class(code: "physical_book", name: "Physical book")
    StoreTaxes::Create.call(
      store: @store,
      actor: @actor,
      name: "Illinois State",
      rate_percent: "5.000",
      calculation_order: 1,
      applies_by_tax_class_id: { @tax.id => true }
    )
    @variant = pos_sellable_variant(actor: @actor, tax_class: @tax)
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 20)
    @register = Register.create!(store: @store, register_number: 1, name: "Front")
    @associate = pos_transacting_user(store: @store, assigned_by: @actor, username: "clerk_ui65c")
    @manager = pos_store_manager(store: @store, assigned_by: @actor, username: "mgr_ui65c")
    sign_in_as("admin")
  end

  test "lookup resolves merchandise without creating a line" do
    post pos_register_enter_path, params: enter_params
    transaction = PosTransaction.working.find_by!(register: @register)

    post pos_register_unlinked_return_lookup_path, params: { identifier: @variant.sku }
    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal "Example Book", payload.fetch("description")
    assert_equal "quantity", payload.fetch("tracking")
    assert_equal false, payload.fetch("quantity_fixed")
    assert_equal 1999, payload.fetch("reference_unit_price_cents")
    assert_equal @variant.id.to_s, payload.fetch("product_variant_id").to_s
    assert_nil payload.fetch("inventory_unit_id")
    assert_equal @tax.id.to_s, payload.fetch("tax_class_id").to_s
    assert_equal 0, transaction.reload.pos_transaction_lines.count
  end

  test "overlay post creates the return line and unlinked_return fact" do
    post pos_register_enter_path, params: enter_params
    transaction = PosTransaction.working.find_by!(register: @register)

    post pos_register_unlinked_return_path, params: {
      lock_version: transaction.lock_version,
      identifier: @variant.sku,
      quantity: 1,
      reason_code: "changed_mind",
      return_price: "18.00",
      expected_product_variant_id: @variant.id,
      expected_reference_unit_price_cents: 1999,
      expected_tax_class_id: @tax.id
    }
    assert_response :success
    transaction.reload
    line = transaction.pos_transaction_lines.first
    assert line.unlinked_return?
    assert_equal 1800, line.selling_unit_price_cents
    assert_equal 1, line.pos_controlled_actions.where(action_type: "unlinked_return").count
    assert_match "Unlinked return", response.body
    assert_match "Reference $19.99", response.body
    assert_match "Return $18.00", response.body
    refute_includes css_select(".pos-lines").text, "Override"
    assert_select "tr[data-direction='return'][data-linked-return='false']"
  end

  test "associate overlay post stays on the workspace until a manager approves" do
    delete session_path
    sign_in_as("clerk_ui65c")
    post pos_register_enter_path, params: enter_params
    transaction = PosTransaction.working.find_by!(register: @register)

    post pos_register_unlinked_return_path, params: {
      lock_version: transaction.lock_version,
      identifier: @variant.sku,
      quantity: 1,
      reason_code: "defective",
      return_price: "19.99"
    }
    assert_response :success
    assert_match "approver credentials are required", response.body
    assert_equal 0, transaction.reload.pos_transaction_lines.count

    post pos_register_unlinked_return_path, params: {
      lock_version: transaction.lock_version,
      identifier: @variant.sku,
      quantity: 1,
      reason_code: "defective",
      return_price: "19.99",
      approver_username: "mgr_ui65c",
      approver_password: "correct-horse-battery"
    }
    assert_response :success
    line = transaction.reload.pos_transaction_lines.first
    assert line.unlinked_return?
    assert_equal @manager.id, line.pos_controlled_actions.first.approved_by_user_id
  end

  test "F8 audits unlinked facts before destroying the line" do
    post pos_register_enter_path, params: enter_params
    transaction = PosTransaction.working.find_by!(register: @register)
    post pos_register_unlinked_return_path, params: {
      lock_version: transaction.lock_version,
      identifier: @variant.sku,
      quantity: 1,
      reason_code: "changed_mind",
      return_price: "19.99"
    }
    line = transaction.reload.pos_transaction_lines.first
    fingerprint = line.pos_controlled_actions.find_by!(action_type: "unlinked_return").action_fingerprint

    post pos_register_remove_path, params: {
      line_id: line.id,
      lock_version: transaction.lock_version
    }
    assert_response :success
    assert_equal 0, transaction.reload.pos_transaction_lines.count
    assert_equal 0, PosControlledAction.where(pos_transaction_line_id: line.id).count

    event = AuditEvent.find_by!(action: "pos.unlinked_return.removed")
    assert_equal line.id, event.subject_id
    assert_equal fingerprint, event.before_values["action_fingerprint"]
    assert_equal 1999, event.before_values["selling_unit_price_cents"]
    assert_equal 1, event.before_values["quantity"]
  end

  test "stale unlinked preview replaces the workspace instead of the overlay" do
    post pos_register_enter_path, params: enter_params
    transaction = PosTransaction.working.find_by!(register: @register)

    post pos_register_unlinked_return_path, params: {
      lock_version: transaction.lock_version,
      identifier: @variant.sku,
      quantity: 1,
      reason_code: "changed_mind",
      return_price: "18.00",
      expected_product_variant_id: @variant.id,
      expected_reference_unit_price_cents: 1,
      expected_tax_class_id: @tax.id
    }, headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_equal 0, transaction.reload.pos_transaction_lines.count
    assert_includes response.body, 'target="pos_workspace"'
    assert_match Pos::ExecuteUnlinkedReturn::STALE_PREVIEW_MESSAGE, response.body
    refute_includes response.body, 'target="pos-unlinked-feedback"'
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end

  def enter_params
    {
      register_id: @register.id,
      opening_float: "0.00",
      confirmed_business_date: BusinessDate.for_store(@store).iso8601
    }
  end
end
