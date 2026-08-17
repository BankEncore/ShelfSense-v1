# frozen_string_literal: true

require "test_helper"

class PosWorkingCommandsTest < ActiveSupport::TestCase
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
    @context = pos_open_context(store: @store, actor: @actor)
  end

  test "add merchandise prices taxes and lock_version rejects a stale retry" do
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    line = Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku,
      quantity: 1
    )
    transaction.reload
    assert_equal 1999, line.extended_selling_amount_cents
    assert_equal 100, line.line_tax_cents
    assert_equal 2099, transaction.total_cents
    assert_equal 0, PosLineTaxComponent.where(pos_transaction_line: line).count

    assert_raises(Pos::StaleObject) do
      Pos::AddMerchandise.call(
        transaction: transaction,
        actor: @actor,
        expected_lock_version: transaction.lock_version - 1,
        identifier: @variant.sku,
        quantity: 1
      )
    end
    assert_equal 1, transaction.reload.pos_transaction_lines.count
  end

  test "cash tender rejects presented less than amount due" do
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku
    )
    transaction.reload
    error = assert_raises(Pos::Error) do
      Pos::TenderCash.call(
        transaction: transaction,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        amount_presented_cents: transaction.total_cents - 1
      )
    end
    assert_match(/less than amount due/, error.message)
  end

  test "cancel working transaction writes audit and consumes no receipt" do
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::CancelTransaction.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version
    )
    assert transaction.reload.cancelled?
    assert_nil transaction.receipt_sequence
    assert AuditEvent.exists?(action: "pos.transaction_cancelled", subject_id: transaction.id)
    assert_raises(ActiveRecord::ReadOnlyRecord) { transaction.update!(subtotal_cents: 1) }
  end

  test "open_price merchandise is rejected" do
    open_price = pos_sellable_variant(actor: @actor, tax_class: @tax, pricing_method: "open_price")
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    error = assert_raises(Pos::Error) do
      Pos::AddMerchandise.call(
        transaction: transaction,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        identifier: open_price.sku
      )
    end
    assert_match(/open-price|sellable|regular price/i, error.message)
  end

  test "unauthorized actor cannot start a transaction" do
    clerk = User.create!(
      username: "no_pos",
      display_name: "No POS",
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    assert_raises(Pos::Denied) do
      Pos::StartTransaction.call(session: @context[:session], actor: clerk)
    end
  end

  test "second cashier cannot close another cashier's session" do
    other = pos_transacting_user(store: @store, assigned_by: @actor, username: "other_close")
    assert_raises(Pos::Denied) do
      Pos::CloseSession.call(
        session: @context[:session],
        actor: other,
        expected_lock_version: @context[:session].lock_version,
        closing_count_cents: 0
      )
    end
    assert @context[:session].reload.open?
  end

  test "second cashier cannot start against another cashier's session" do
    other = pos_transacting_user(store: @store, assigned_by: @actor, username: "other_start")
    assert_raises(Pos::Denied) do
      Pos::StartTransaction.call(session: @context[:session], actor: other)
    end
    assert_equal 0, PosTransaction.where(pos_session: @context[:session]).count
  end

  test "second cashier cannot mutate another cashier's working transaction" do
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    line = Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku
    )
    transaction.reload
    other = pos_transacting_user(store: @store, assigned_by: @actor, username: "other_mutate")

    assert_raises(Pos::Denied) do
      Pos::AddMerchandise.call(
        transaction: transaction,
        actor: other,
        expected_lock_version: transaction.lock_version,
        identifier: @variant.sku
      )
    end
    assert_raises(Pos::Denied) do
      Pos::ChangeQuantity.call(
        transaction: transaction,
        line: line,
        actor: other,
        expected_lock_version: transaction.lock_version,
        quantity: 2
      )
    end
    assert_raises(Pos::Denied) do
      Pos::RemoveWorkingLine.call(
        transaction: transaction,
        line: line,
        actor: other,
        expected_lock_version: transaction.lock_version
      )
    end
    assert_raises(Pos::Denied) do
      Pos::TenderCash.call(
        transaction: transaction,
        actor: other,
        expected_lock_version: transaction.lock_version,
        amount_presented_cents: 2500
      )
    end
    assert_raises(Pos::Denied) do
      Pos::CancelTransaction.call(
        transaction: transaction,
        actor: other,
        expected_lock_version: transaction.lock_version
      )
    end
    assert transaction.reload.working?
    assert_equal 1, transaction.pos_transaction_lines.count
  end

  test "inactive store rejects POS commands" do
    @store.active = false
    assert_not @store.valid?
    assert_includes @store.errors[:base], "cannot deactivate while an open reporting period exists"

    Pos::CloseSession.call(
      session: @context[:session],
      actor: @actor,
      expected_lock_version: @context[:session].lock_version,
      closing_count_cents: 0
    )
    Pos::FinalizeReportingPeriod.call(
      period: @context[:period],
      actor: @actor,
      expected_lock_version: @context[:period].lock_version
    )
    @store.update!(active: false, deactivated_at: Time.current, deactivated_by: @actor)

    error = assert_raises(Pos::Error) do
      Pos::OpenReportingPeriod.call(store: @store, register: @context[:register], actor: @actor)
    end
    assert_match(/store is not active/, error.message)
  end

  test "inactive register rejects POS commands" do
    Pos::CloseSession.call(
      session: @context[:session],
      actor: @actor,
      expected_lock_version: @context[:session].lock_version,
      closing_count_cents: 0
    )
    Pos::FinalizeReportingPeriod.call(
      period: @context[:period],
      actor: @actor,
      expected_lock_version: @context[:period].lock_version
    )
    @context[:register].update!(active: false, deactivated_at: Time.current, deactivated_by: @actor)

    error = assert_raises(Pos::Error) do
      Pos::OpenReportingPeriod.call(store: @store, register: @context[:register], actor: @actor)
    end
    assert_match(/register is not active/, error.message)
  end

  test "change quantity and remove working line recompute totals without tax components" do
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    line = Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku,
      quantity: 1
    )
    transaction.reload
    Pos::ChangeQuantity.call(
      transaction: transaction,
      line: line,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      quantity: 2
    )
    transaction.reload
    assert_equal 3998, transaction.subtotal_cents
    assert_equal 200, transaction.tax_cents
    assert_equal 0, PosLineTaxComponent.where(pos_transaction_line: line).count

    Pos::RemoveWorkingLine.call(
      transaction: transaction,
      line: line,
      actor: @actor,
      expected_lock_version: transaction.lock_version
    )
    assert_equal 0, transaction.reload.pos_transaction_lines.count
    assert_equal 0, transaction.total_cents
  end

  test "cash tender records presented applied and change" do
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku
    )
    transaction.reload
    tender = Pos::TenderCash.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: 2500
    )
    assert_equal 2099, tender.amount_cents
    assert_equal 2500, tender.amount_presented_cents
    assert_equal 401, tender.change_cents
  end

  test "close session rejects a working transaction and succeeds after cancel" do
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    session = @context[:session]
    error = assert_raises(Pos::Error) do
      Pos::CloseSession.call(
        session: session,
        actor: @actor,
        expected_lock_version: session.lock_version,
        closing_count_cents: 0
      )
    end
    assert_match(/working transaction/, error.message)

    Pos::CancelTransaction.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version
    )
    session.reload
    Pos::CloseSession.call(
      session: session,
      actor: @actor,
      expected_lock_version: session.lock_version,
      closing_count_cents: 0
    )
    assert session.reload.closed?
  end

  test "individually tracked merchandise is rejected" do
    used_class = merchandise_class(
      code: "pos_used_#{SecureRandom.hex(3)}",
      used_merchandise_allowed: true,
      default_standard_department: department(code: "pos_used_d_#{SecureRandom.hex(3)}", default_tax_class: @tax),
      default_used_department: department(code: "pos_used_u_#{SecureRandom.hex(3)}", default_tax_class: @tax),
      pricing_method: "fixed"
    )
    product = Products::Create.call(
      attributes: { name: "Used Book", status: "active" },
      actor: @actor,
      identifier_mode: "generate"
    )
    used = ProductVariants::Create.call(
      product: product,
      attributes: {
        variant_type: "used",
        status: "active",
        merchandise_class_id: used_class.id,
        merchandise_condition_id: merchandise_condition(code: "pos_good_#{SecureRandom.hex(2)}").id,
        department_id: used_class.default_used_department_id,
        tax_class_id: @tax.id,
        regular_price_cents: 1200
      },
      actor: @actor
    )
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    error = assert_raises(Pos::Error) do
      Pos::AddMerchandise.call(
        transaction: transaction,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        identifier: used.sku
      )
    end
    assert_match(/individually tracked/, error.message)
  end
end
