# frozen_string_literal: true

require "test_helper"

class PosControlledActionsTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @admin = @bootstrap[:administrator]
    @book = tax_class(code: "physical_book", name: "Physical book")
    @food = tax_class(code: "prepared_food", name: "Prepared food")
    StoreTaxes::Create.call(
      store: @store,
      actor: @admin,
      name: "Illinois State",
      rate_percent: "5.000",
      calculation_order: 1,
      applies_by_tax_class_id: { @book.id => true, @food.id => true }
    )
    @variant = pos_sellable_variant(actor: @admin, tax_class: @book)
    open_quantity_stock(store: @store, variant: @variant, actor: @admin, quantity: 20)
    @associate = pos_transacting_user(store: @store, assigned_by: @admin, username: "clerk64")
    @manager = pos_store_manager(store: @store, assigned_by: @admin, username: "mgr64")
  end

  test "10 percent of 1999 and 2000 round half up" do
    assert_equal 200, Pos::LineDiscount.amount_cents(selling_unit_price_cents: 1999, quantity: 1, basis_points: 1000)
    assert_equal 200, Pos::LineDiscount.amount_cents(selling_unit_price_cents: 2000, quantity: 1, basis_points: 1000)
  end

  test "manager cashier applies a price override as direct" do
    transaction, line = start_sale(@manager)

    apply_action(
      transaction, line, @manager,
      action_type: "price_override",
      operation: "apply",
      reason_code: "shelf_price_mismatch",
      selling_unit_price_cents: 1800
    )

    line.reload
    action = line.pos_controlled_actions.find_by!(action_type: "price_override")
    assert_equal 1999, line.reference_unit_price_cents
    assert_equal 1800, line.selling_unit_price_cents
    assert_equal 1800, line.net_merchandise_amount_cents
    assert_equal "direct", action.policy_result
    assert_nil action.approved_by_user_id
    assert AuditEvent.exists?(action: "pos.price_override.applied", subject_id: line.id)
  end

  test "associate override requires a store manager and does not create a manager session" do
    transaction, line = start_sale(@associate)
    sessions_before = PosSession.count

    apply_action(
      transaction, line, @associate,
      action_type: "price_override",
      operation: "apply",
      reason_code: "damaged",
      selling_unit_price_cents: 1500,
      approver_username: "mgr64",
      approver_password: "correct-horse-battery"
    )

    line.reload
    action = line.pos_controlled_actions.find_by!(action_type: "price_override")
    assert_equal "approval_required", action.policy_result
    assert_equal @manager.id, action.approved_by_user_id
    assert_equal @associate.id, action.performed_by_user_id
    assert_equal sessions_before, PosSession.count
    assert_equal @associate.id, transaction.cashier_user_id
    assert AuditEvent.exists?(action: "pos.controlled_action.approved", actor_user_id: @manager.id)
  end

  test "self-approval is rejected" do
    transaction, line = start_sale(@associate)

    error = assert_raises(Pos::OverlayFailure) do
      apply_action(
        transaction, line, @associate,
        action_type: "price_override",
        operation: "apply",
        reason_code: "damaged",
        selling_unit_price_cents: 1500,
        approver_username: "clerk64",
        approver_password: "correct-horse-battery"
      )
    end
    assert_equal :authorization_prohibited, error.kind
    assert_match(/You cannot approve your own action/, error.message)
    assert_equal 1999, line.reload.selling_unit_price_cents
    assert AuditEvent.exists?(action: "pos.controlled_action.denied")
  end

  test "a manager assigned only to another store cannot approve" do
    east = Store.create!(store_number: "2", code: "east", name: "East", legal_name: "Example Books LLC", timezone: "America/New_York", country_code: "US")
    other = pos_store_manager(store: east, assigned_by: @admin, username: "eastmgr")
    transaction, line = start_sale(@associate)

    error = assert_raises(Pos::OverlayFailure) do
      apply_action(
        transaction, line, @associate,
        action_type: "price_override",
        operation: "apply",
        reason_code: "damaged",
        selling_unit_price_cents: 1500,
        approver_username: "eastmgr",
        approver_password: "correct-horse-battery"
      )
    end
    assert_equal :authorization_prohibited, error.kind
    assert_match(/This manager cannot authorize/, error.message)
    assert_equal other.username, "eastmgr"
    assert_equal 0, line.reload.pos_controlled_actions.count
  end

  test "stale lock_version rejects the request" do
    transaction, line = start_sale(@manager)
    stale = transaction.lock_version

    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @manager,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku
    )
    transaction.reload

    assert_raises(Pos::StaleObject) do
      Pos::ExecuteControlledAction.call(
        transaction: transaction,
        line: line,
        actor: @manager,
        expected_lock_version: stale,
        action_type: "price_override",
        operation: "apply",
        reason_code: "damaged",
        selling_unit_price_cents: 1500
      )
    end
  end

  test "reason is material to the fingerprint" do
    transaction, line = start_sale(@manager)
    apply_action(
      transaction, line, @manager,
      action_type: "price_override",
      operation: "apply",
      reason_code: "shelf_price_mismatch",
      selling_unit_price_cents: 1800
    )
    first = line.reload.pos_controlled_actions.find_by!(action_type: "price_override").action_fingerprint

    apply_action(
      transaction.reload, line, @manager,
      action_type: "price_override",
      operation: "apply",
      reason_code: "damaged",
      selling_unit_price_cents: 1800
    )
    second = line.reload.pos_controlled_actions.find_by!(action_type: "price_override").action_fingerprint
    assert_not_equal first, second
  end

  test "completion refuses a Core and fact mismatch" do
    transaction, line = start_sale(@manager)
    apply_action(
      transaction, line, @manager,
      action_type: "price_override",
      operation: "apply",
      reason_code: "damaged",
      selling_unit_price_cents: 1500
    )
    line.update_columns(selling_unit_price_cents: line.reference_unit_price_cents)

    error = assert_raises(Pos::Error) { complete!(transaction.reload, @manager) }
    assert_match(/price override fact/, error.message)
  end

  test "completion refuses a fingerprint mismatch" do
    transaction, line = start_sale(@manager)
    apply_action(
      transaction, line, @manager,
      action_type: "price_override",
      operation: "apply",
      reason_code: "damaged",
      selling_unit_price_cents: 1500
    )
    line.pos_controlled_actions.find_by!(action_type: "price_override").update_columns(action_fingerprint: "deadbeef")
    tender!(transaction.reload, @manager)

    error = assert_raises(Pos::Error) { complete!(transaction.reload, @manager) }
    assert_match(/fingerprint/, error.message)
  end

  test "line discount reduces net without rewriting selling and taxes net" do
    transaction, line = start_sale(@manager)
    apply_action(
      transaction, line, @manager,
      action_type: "line_discount",
      operation: "apply",
      reason_code: "customer_service",
      discount_basis_points: 1000
    )

    line.reload
    transaction.reload
    assert_equal 1999, line.selling_unit_price_cents
    assert_equal 1999, line.extended_selling_amount_cents
    assert_equal 1000, line.manual_discount_basis_points
    assert_equal 200, line.manual_discount_cents
    assert_equal 1799, line.net_merchandise_amount_cents
    assert_equal 90, line.line_tax_cents
    assert_equal 200, transaction.discount_cents
    assert_equal 1889, transaction.total_cents
  end

  test "a discount that rounds to zero cents is rejected" do
    transaction, line = start_sale(@manager)
    error = assert_raises(Pos::Error) do
      apply_action(
        transaction, line, @manager,
        action_type: "line_discount",
        operation: "apply",
        reason_code: "damaged",
        discount_basis_points: 1
      )
    end
    assert_match(/must change the amount charged/, error.message)
    assert_nil line.reload.manual_discount_basis_points
  end

  test "100 percent discount completes with no tender" do
    transaction, line = start_sale(@manager)
    apply_action(
      transaction, line, @manager,
      action_type: "line_discount",
      operation: "apply",
      reason_code: "manager_discretion",
      discount_basis_points: 10_000
    )
    transaction.reload
    assert_equal 0, transaction.total_cents
    assert_equal 0, transaction.pos_tenders.count

    result = complete!(transaction, @manager)
    assert result.transaction.completed?
    assert_equal 0, result.transaction.pos_tenders.count
    assert_equal [], result.operation.envelope.fetch("tenders")
  end

  test "positive-total sales still require a tender" do
    transaction, _line = start_sale(@manager)
    error = assert_raises(Pos::Error) { complete!(transaction, @manager) }
    assert_match(/tender is required/, error.message)
  end

  test "rescan does not merge a discounted line" do
    transaction, line = start_sale(@manager)
    apply_action(
      transaction, line, @manager,
      action_type: "line_discount",
      operation: "apply",
      reason_code: "damaged",
      discount_basis_points: 1000
    )
    Pos::AddMerchandise.call(
      transaction: transaction.reload,
      actor: @manager,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku
    )
    assert_equal 2, transaction.reload.pos_transaction_lines.count
    assert_equal 1, line.reload.quantity
  end

  test "quantity is blocked on override and discount lines but not Tax Class override" do
    transaction, line = start_sale(@manager)
    apply_action(
      transaction, line, @manager,
      action_type: "price_override",
      operation: "apply",
      reason_code: "damaged",
      selling_unit_price_cents: 1500
    )
    error = assert_raises(Pos::Error) do
      Pos::ChangeQuantity.call(
        transaction: transaction.reload,
        line: line.reload,
        actor: @manager,
        expected_lock_version: transaction.lock_version,
        quantity: 2
      )
    end
    assert_equal "Remove the price override or discount before changing quantity.", error.message

    apply_action(
      transaction.reload, line.reload, @manager,
      action_type: "price_override",
      operation: "remove"
    )
    apply_action(
      transaction.reload, line.reload, @manager,
      action_type: "tax_class_override",
      operation: "apply",
      reason_code: "classification_correction",
      tax_class_id: @food.id
    )
    Pos::ChangeQuantity.call(
      transaction: transaction.reload,
      line: line.reload,
      actor: @manager,
      expected_lock_version: transaction.lock_version,
      quantity: 2
    )
    assert_equal 2, line.reload.quantity
  end

  test "inactive and unresolved Tax Classes are rejected" do
    transaction, line = start_sale(@manager)
    inactive = tax_class(code: "inactive_class", name: "Inactive", active: false)
    error = assert_raises(Pos::Error) do
      apply_action(
        transaction, line, @manager,
        action_type: "tax_class_override",
        operation: "apply",
        reason_code: "classification_correction",
        tax_class_id: inactive.id
      )
    end
    assert_match(/not valid/, error.message)

    unresolved = tax_class(code: "periodicals", name: "Periodicals")
    error = assert_raises(Pos::Error) do
      apply_action(
        transaction.reload, line.reload, @manager,
        action_type: "tax_class_override",
        operation: "apply",
        reason_code: "classification_correction",
        tax_class_id: unresolved.id
      )
    end
    assert_match(/unresolved|not valid|applicab/i, error.message)
  end

  test "override discount and Tax Class coexist and clear working tenders" do
    transaction, line = start_sale(@manager)
    Pos::TenderCash.call(
      transaction: transaction,
      actor: @manager,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: 2500
    )
    assert_equal 1, transaction.reload.pos_tenders.count

    apply_action(
      transaction.reload, line, @manager,
      action_type: "price_override",
      operation: "apply",
      reason_code: "price_match",
      selling_unit_price_cents: 2000
    )
    assert_equal 0, transaction.reload.pos_tenders.count

    apply_action(
      transaction.reload, line.reload, @manager,
      action_type: "line_discount",
      operation: "apply",
      reason_code: "customer_service",
      discount_basis_points: 1000
    )
    apply_action(
      transaction.reload, line.reload, @manager,
      action_type: "tax_class_override",
      operation: "apply",
      reason_code: "classification_correction",
      tax_class_id: @food.id
    )

    line.reload
    transaction.reload
    assert_equal 1999, line.reference_unit_price_cents
    assert_equal 2000, line.selling_unit_price_cents
    assert_equal 200, line.manual_discount_cents
    assert_equal 1800, line.net_merchandise_amount_cents
    assert_equal 90, line.line_tax_cents
    assert_equal @food.id, line.tax_class_id
    assert_equal @book.id, line.default_tax_class_id
    assert_equal 3, line.pos_controlled_actions.count

    tender!(transaction, @manager)
    result = complete!(transaction.reload, @manager)
    envelope = result.operation.envelope
    assert envelope.dig("lines", 0, "override")
    assert envelope.dig("lines", 0, "discount")
    assert_equal @book.id.to_s, envelope.dig("lines", 0, "default_tax_class_id")
    assert_equal 3, envelope.fetch("controlled_actions").size
  end

  test "cannot change a price override while a discount exists" do
    transaction, line = start_sale(@manager)
    apply_action(
      transaction, line, @manager,
      action_type: "price_override",
      operation: "apply",
      reason_code: "damaged",
      selling_unit_price_cents: 1800
    )
    apply_action(
      transaction.reload, line.reload, @manager,
      action_type: "line_discount",
      operation: "apply",
      reason_code: "damaged",
      discount_basis_points: 1000
    )
    error = assert_raises(Pos::Error) do
      apply_action(
        transaction.reload, line.reload, @manager,
        action_type: "price_override",
        operation: "apply",
        reason_code: "price_match",
        selling_unit_price_cents: 1700
      )
    end
    assert_match(/remove the line discount/, error.message)
  end

  test "verify accepts a pre-6.4 v2 envelope without controlled action keys" do
    payload = JSON.parse(File.read(Rails.root.join("test/fixtures/files/pos/completed_pos_operation_v2/cash_sale.json")))
    Pos::CompletedTransactionFacts.new(payload).verify!
    refute payload.fetch("lines").first.key?("override")
    refute payload.key?("controlled_actions")
  end

  test "completion refuses stored material_values that do not match Core" do
    transaction, line = start_sale(@manager)
    apply_action(
      transaction, line, @manager,
      action_type: "price_override",
      operation: "apply",
      reason_code: "damaged",
      selling_unit_price_cents: 1500
    )
    action = line.pos_controlled_actions.find_by!(action_type: "price_override")
    action.update_columns(material_values: action.material_values.merge("requested_selling_unit_price_cents" => 500))
    tender!(transaction.reload, @manager)

    error = assert_raises(Pos::Error) { complete!(transaction.reload, @manager) }
    assert_match(/material values/, error.message)
  end

  test "verify requires the complete 6.4 controlled_actions shape when present" do
    payload = completed_override_envelope
    Pos::CompletedTransactionFacts.new(payload).verify!

    missing_subject = payload.deep_dup
    missing_subject["controlled_actions"].first.delete("subject")
    error = assert_raises(Pos::Error) { Pos::CompletedTransactionFacts.new(missing_subject).verify! }
    assert_match(/subject line_id/, error.message)

    missing_reason = payload.deep_dup
    missing_reason["controlled_actions"].first.delete("reason")
    error = assert_raises(Pos::Error) { Pos::CompletedTransactionFacts.new(missing_reason).verify! }
    assert_match(/reason/, error.message)

    missing_version = payload.deep_dup
    missing_version["controlled_actions"].first["policy_context"].delete("version")
    error = assert_raises(Pos::Error) { Pos::CompletedTransactionFacts.new(missing_version).verify! }
    assert_match(/policy version/, error.message)

    missing_material = payload.deep_dup
    missing_material["controlled_actions"].first.delete("material_values")
    error = assert_raises(Pos::Error) { Pos::CompletedTransactionFacts.new(missing_material).verify! }
    assert_match(/material_values/, error.message)

    missing_executed = payload.deep_dup
    missing_executed["controlled_actions"].first.delete("executed_at")
    error = assert_raises(Pos::Error) { Pos::CompletedTransactionFacts.new(missing_executed).verify! }
    assert_match(/executed_at/, error.message)
  end

  test "verify requires approver name when a controlled action needed approval" do
    transaction, line = start_sale(@associate)
    apply_action(
      transaction, line, @associate,
      action_type: "price_override",
      operation: "apply",
      reason_code: "damaged",
      selling_unit_price_cents: 1500,
      approver_username: "mgr64",
      approver_password: "correct-horse-battery"
    )
    tender!(transaction.reload, @associate)
    payload = complete!(transaction.reload, @associate).operation.envelope.deep_dup
    Pos::CompletedTransactionFacts.new(payload).verify!

    payload["controlled_actions"].first.delete("approved_by_name")
    error = assert_raises(Pos::Error) { Pos::CompletedTransactionFacts.new(payload).verify! }
    assert_match(/approved_by_name/, error.message)
  end

  test "tax class name backfill does not copy live names onto completed lines" do
    transaction, completed_line = start_sale(@manager)
    tender!(transaction, @manager)
    complete!(transaction.reload, @manager)
    _working_transaction, working_line = start_sale(@manager)

    PosTransactionLine.where(id: [ completed_line.id, working_line.id ]).update_all(
      default_tax_class_id: nil,
      default_tax_class_code_snapshot: nil,
      default_tax_class_name_snapshot: nil,
      tax_class_name_snapshot: nil
    )
    @book.update_columns(name: "Books — Physical")

    ActiveRecord::Base.connection.execute(<<~SQL)
      UPDATE pos_transaction_lines
      SET default_tax_class_id = tax_class_id,
          default_tax_class_code_snapshot = tax_class_code_snapshot
      WHERE default_tax_class_id IS NULL
    SQL
    ActiveRecord::Base.connection.execute(<<~SQL)
      UPDATE pos_transaction_lines AS l
      SET default_tax_class_name_snapshot = t.name,
          tax_class_name_snapshot = t.name
      FROM tax_classes AS t, pos_transactions AS tx
      WHERE t.id = l.tax_class_id
        AND tx.id = l.pos_transaction_id
        AND tx.status = 'working'
    SQL

    completed_line.reload
    working_line.reload
    assert_equal @book.id, completed_line.default_tax_class_id
    assert_equal "physical_book", completed_line.default_tax_class_code_snapshot
    assert_nil completed_line.default_tax_class_name_snapshot
    assert_nil completed_line.tax_class_name_snapshot
    assert_equal "Books — Physical", working_line.default_tax_class_name_snapshot
    assert_equal "Books — Physical", working_line.tax_class_name_snapshot
  end

  private

  def start_sale(actor)
    context = pos_open_context(store: @store, actor: actor)
    transaction = Pos::StartTransaction.call(session: context[:session], actor: actor)
    line = Pos::AddMerchandise.call(
      transaction: transaction,
      actor: actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku
    )
    [ transaction.reload, line ]
  end

  def apply_action(transaction, line, actor, **attrs)
    Pos::ExecuteControlledAction.call(
      transaction: transaction,
      line: line,
      actor: actor,
      expected_lock_version: transaction.lock_version,
      **attrs
    )
    transaction.reload
    line.reload
  end

  def tender!(transaction, actor)
    Pos::TenderCash.call(
      transaction: transaction,
      actor: actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: [ transaction.total_cents, 1 ].max
    )
    transaction.reload
  end

  def complete!(transaction, actor)
    Pos::CompleteTransaction.call(
      transaction: transaction,
      actor: actor,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents
    )
  end

  def completed_override_envelope
    transaction, line = start_sale(@manager)
    apply_action(
      transaction, line, @manager,
      action_type: "price_override",
      operation: "apply",
      reason_code: "damaged",
      selling_unit_price_cents: 1500
    )
    tender!(transaction.reload, @manager)
    complete!(transaction.reload, @manager).operation.envelope.deep_dup
  end
end
