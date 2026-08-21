# frozen_string_literal: true

require "test_helper"

class PosMerchandiseBreadthTest < ActiveSupport::TestCase
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
    @standard = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Example Book")
    open_quantity_stock(store: @store, variant: @standard, actor: @actor, quantity: 5, unit_cost_cents: 100)
    @used_variant, @unit = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax, name: "Used Book")
    @non_inventory = pos_sellable_variant(
      actor: @actor,
      tax_class: @tax,
      inventory_mode: "non_inventory",
      name: "Store Service"
    )
    @context = pos_open_context(store: @store, actor: @actor)
  end

  test "adds an on-hand unit and rejects a used variant sku" do
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    line = Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @unit.unit_identifier
    )

    assert_equal @unit.id, line.inventory_unit_id
    assert_equal 1, line.quantity
    assert_equal @unit.effective_regular_price_cents, line.selling_unit_price_cents

    error = assert_raises(Pos::Error) do
      Pos::AddMerchandise.call(
        transaction: transaction.reload,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        identifier: @used_variant.sku
      )
    end
    assert_match(/scan the unit identifier/, error.message)
    assert_equal 1, transaction.reload.pos_transaction_lines.count
  end

  test "adds non-inventory merchandise without an inventory unit" do
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    line = Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @non_inventory.sku
    )

    assert_nil line.inventory_unit_id
    assert_equal "non_inventory", line.product_variant.derived_inventory_tracking
    assert_equal 1, line.quantity
  end

  test "rejects a second working add of the same unit from another session" do
    first = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: first,
      actor: @actor,
      expected_lock_version: first.lock_version,
      identifier: @unit.unit_identifier
    )

    other = pos_open_context(store: @store, actor: @actor)
    second = Pos::StartTransaction.call(session: other[:session], actor: @actor)
    error = assert_raises(Pos::Error) do
      Pos::AddMerchandise.call(
        transaction: second,
        actor: @actor,
        expected_lock_version: second.lock_version,
        identifier: @unit.unit_identifier
      )
    end
    assert_match(/already on a working transaction/, error.message)
    assert_equal 0, second.reload.pos_transaction_lines.count
  end

  test "change quantity rejects a quantity other than one on a unit line" do
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    line = Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @unit.unit_identifier
    )
    transaction.reload
    error = assert_raises(Pos::Error) do
      Pos::ChangeQuantity.call(
        transaction: transaction,
        line: line,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        quantity: 2
      )
    end
    assert_match(/must be 1/, error.message)
    assert_equal 1, line.reload.quantity
  end

  test "completes a mixed cash basket and posts inventory only for tracked lines" do
    transaction = mixed_working_transaction
    tender_cash!(transaction)
    result = complete!(transaction)

    transaction = result.transaction
    envelope = result.operation.envelope
    standard_line = transaction.pos_transaction_lines.find_by!(product_variant_id: @standard.id)
    unit_line = transaction.pos_transaction_lines.find_by!(inventory_unit_id: @unit.id)
    service_line = transaction.pos_transaction_lines.find_by!(product_variant_id: @non_inventory.id)

    assert_equal 2, envelope.fetch("schema_version")
    assert_equal transaction.total_cents, envelope.fetch("transaction").fetch("signed_net_cents")
    assert_equal @unit.id.to_s, envelope.fetch("lines").find { |line| line["inventory_unit_id"] }.fetch("inventory_unit_id")
    refute envelope.fetch("lines").find { |line| line["product_variant_id"] == @standard.id }.key?("inventory_unit_id")
    assert_equal @unit.unit_identifier, unit_line.merchandise_snapshot.fetch("unit_identifier")
    assert_equal @used_variant.merchandise_condition.code, unit_line.merchandise_snapshot.fetch("condition_code")
    assert_equal @used_variant.merchandise_condition.name, unit_line.merchandise_snapshot.fetch("condition_name")

    standard_balance = InventoryBalance.find_by!(store: @store, product_variant: @standard)
    assert_equal 3, standard_balance.on_hand_quantity
    assert @unit.reload.removed?
    sale = InventoryLedgerEntry.find_by!(source_type: "PosTransactionLine", source_id: unit_line.id)
    assert_equal "sale", sale.entry_type
    assert_equal(-1, sale.quantity_delta)
    assert_equal @unit.id, sale.inventory_unit_id
    assert_equal 0, InventoryLedgerEntry.where(source_type: "PosTransactionLine", source_id: service_line.id).count
    assert_equal 0, InventoryValuationEntry.where(source_type: "PosTransactionLine", source_id: service_line.id).count
    assert_nil InventoryBalance.find_by(store: @store, product_variant: @non_inventory)
    assert_equal 0, InventoryLedgerEntry.where(source_type: "PosTransactionLine", source_id: standard_line.id, inventory_unit_id: nil).where.not(quantity_delta: -2).count
    assert_equal(-2, InventoryLedgerEntry.find_by!(source_type: "PosTransactionLine", source_id: standard_line.id).quantity_delta)
    assert_equal 2, OutboxMessage.where(event_type: "inventory.sale_posted").count
    assert AuditEvent.exists?(action: "pos.transaction_completed", subject_id: transaction.id)
    audit = AuditEvent.find_by!(action: "pos.transaction_completed", subject_id: transaction.id)
    assert_equal @unit.id.to_s, audit.after_values.fetch("inventory_unit_id").to_s
    refute_includes audit.after_values.to_s, "carrying_value"
  end

  test "completion fails when the unit leaves on-hand after add" do
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @unit.unit_identifier
    )
    Inventory::PostAdjustment.call(
      store: @store,
      product_variant: @used_variant,
      adjustment_reason: AdjustmentReason.find_by!(code: "shrinkage"),
      quantity_delta: -1,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      unit_identifier: @unit.unit_identifier
    )
    transaction.reload
    tender_cash!(transaction)
    error = assert_raises(Pos::Error) do
      complete!(transaction)
    end

    assert_match(/not on hand/, error.message)
    assert transaction.reload.working?
    assert_nil transaction.receipt_sequence
    assert_equal 0, @context[:register].reload.receipt_sequence
    assert_equal 0, InventoryLedgerEntry.where(source_type: "PosTransactionLine").count
    assert_equal 0, OutboxMessage.where(event_type: "inventory.sale_posted").count
    assert @unit.reload.removed?
  end

  test "idempotent complete does not double-remove the unit" do
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @unit.unit_identifier
    )
    transaction.reload
    tender_cash!(transaction)
    operation_id = SecureRandom.uuid_v7
    first = complete!(transaction, operation_id: operation_id)
    second = complete!(transaction, operation_id: operation_id)

    assert second.replayed
    assert_equal first.operation.envelope_hash, second.operation.envelope_hash
    assert @unit.reload.removed?
    assert_equal 1, InventoryLedgerEntry.where(source_type: "PosTransactionLine", inventory_unit_id: @unit.id).count
    assert_equal 1, OutboxMessage.where(event_type: "inventory.sale_posted").count
  end

  test "unit regular price takes precedence over the variant regular price" do
    variant, unit = pos_on_hand_unit(
      store: @store,
      actor: @actor,
      tax_class: @tax,
      name: "Priced Used Book",
      regular_price_cents: 900
    )
    assert_equal 1200, variant.regular_price_cents
    assert_equal 900, unit.regular_price_cents

    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    line = Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: unit.unit_identifier
    )

    assert_equal 900, line.selling_unit_price_cents
    assert_equal 900, line.reference_unit_price_cents
  end

  test "rejects a used unit that belongs to another store" do
    other = Store.create!(
      store_number: (@store.store_number || 1) + 50,
      code: "east_#{SecureRandom.hex(3)}",
      name: "East Store",
      legal_name: "Example Books LLC",
      timezone: "America/New_York",
      country_code: "US"
    )
    _variant, unit = pos_on_hand_unit(store: other, actor: @actor, tax_class: @tax, name: "East Used Book")
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    error = assert_raises(Pos::Error) do
      Pos::AddMerchandise.call(
        transaction: transaction,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        identifier: unit.unit_identifier
      )
    end
    assert_match(/not at this store/, error.message)
    assert_equal 0, transaction.reload.pos_transaction_lines.count
  end

  test "rejects an already-removed unit at scan" do
    Inventory::PostAdjustment.call(
      store: @store,
      product_variant: @used_variant,
      adjustment_reason: AdjustmentReason.find_by!(code: "shrinkage"),
      quantity_delta: -1,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      unit_identifier: @unit.unit_identifier
    )
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    error = assert_raises(Pos::Error) do
      Pos::AddMerchandise.call(
        transaction: transaction,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        identifier: @unit.unit_identifier
      )
    end
    assert_match(/not on hand/, error.message)
    assert_equal 0, transaction.reload.pos_transaction_lines.count
  end

  private

  def mixed_working_transaction
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @standard.sku,
      quantity: 2
    )
    transaction.reload
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @unit.unit_identifier
    )
    transaction.reload
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @non_inventory.sku
    )
    transaction.reload
  end

  def tender_cash!(transaction, amount_presented_cents: 20_000)
    Pos::TenderCash.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: amount_presented_cents
    )
    transaction.reload
  end

  def complete!(transaction, operation_id: SecureRandom.uuid_v7, amount_presented_cents: 20_000)
    Pos::CompleteTransaction.call(
      transaction: transaction,
      actor: @actor,
      operation_id: operation_id,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents
    )
  end
end
