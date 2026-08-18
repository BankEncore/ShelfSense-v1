# frozen_string_literal: true

require "test_helper"

class InventoryPostSaleTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    Inventory::AdjustmentReasons.seed!
    @tax = tax_class(code: "sale_tax")
    @variant = pos_sellable_variant(actor: @actor, tax_class: @tax)
    @context = pos_open_context(store: @store, actor: @actor)
    @transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    @line = Pos::AddMerchandise.call(
      transaction: @transaction,
      actor: @actor,
      expected_lock_version: @transaction.lock_version,
      identifier: @variant.sku,
      quantity: 2
    )
    @occurred_at = Time.utc(2026, 8, 16, 18, 4, 22)
    @business_date = Date.new(2026, 8, 15)
  end

  test "posts paired sale effects and sale_posted outbox without an adjustment" do
    open_stock(5, 100)
    result = nil
    PosTransaction.transaction do
      result = Inventory::PostSale.call(
        line: @line,
        occurred_at: @occurred_at,
        business_date: @business_date,
        actor: @actor
      )
    end

    ledger = result.fetch(:ledger)
    valuation = result.fetch(:valuation)
    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)

    assert_equal(-2, ledger.quantity_delta)
    assert_equal "sale", ledger.entry_type
    assert_equal "PosTransactionLine", ledger.source_type
    assert_equal @line.id, ledger.source_id
    assert_equal @business_date, ledger.business_date
    assert_equal @occurred_at, ledger.occurred_at
    assert_equal(-2, valuation.quantity_delta)
    assert_equal(-200, valuation.value_delta_cents)
    assert_equal "depletion", valuation.entry_type
    assert_equal 3, balance.on_hand_quantity
    assert_equal 300, balance.inventory_value_cents
    assert_equal 1, InventoryAdjustment.count
    assert_equal 1, OutboxMessage.where(event_type: "inventory.sale_posted").count
    assert_equal 1, OutboxMessage.where(event_type: "inventory.adjustment_posted").count
    assert_empty Inventory::LedgerPairIntegrity.drifts(store_id: @store.id, product_variant_id: @variant.id)
  end

  test "reject_below_zero leaves no sale effect" do
    error = assert_raises(Inventory::PostSale::Error) do
      PosTransaction.transaction do
        Inventory::PostSale.call(
          line: @line,
          occurred_at: @occurred_at,
          business_date: @business_date,
          actor: @actor
        )
      end
    end
    assert_match(/insufficient|below zero/i, error.message)
    assert_equal 0, InventoryLedgerEntry.where(source_type: "PosTransactionLine").count
    assert_equal 0, OutboxMessage.where(event_type: "inventory.sale_posted").count
  end

  test "duplicate source effect is rejected" do
    open_stock(5, 100)
    PosTransaction.transaction do
      Inventory::PostSale.call(
        line: @line,
        occurred_at: @occurred_at,
        business_date: @business_date,
        actor: @actor
      )
    end
    assert_raises(ActiveRecord::RecordNotUnique) do
      PosTransaction.transaction do
        Inventory::PostSale.call(
          line: @line,
          occurred_at: @occurred_at,
          business_date: @business_date,
          actor: @actor
        )
      end
    end
  end

  test "posts specific-identification removal for an individual unit" do
    used_variant, unit = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax, name: "Used Sale")
    line = Pos::AddMerchandise.call(
      transaction: @transaction.reload,
      actor: @actor,
      expected_lock_version: @transaction.lock_version,
      identifier: unit.unit_identifier
    )
    result = nil
    PosTransaction.transaction do
      result = Inventory::PostSale.call(
        line: line,
        occurred_at: @occurred_at,
        business_date: @business_date,
        actor: @actor
      )
    end

    ledger = result.fetch(:ledger)
    valuation = result.fetch(:valuation)
    balance = InventoryBalance.find_by!(store: @store, product_variant: used_variant)

    assert unit.reload.removed?
    assert_equal(-1, ledger.quantity_delta)
    assert_equal "sale", ledger.entry_type
    assert_equal unit.id, ledger.inventory_unit_id
    assert_equal "specific_identification", valuation.valuation_method
    assert_equal(-unit.carrying_value_cents, valuation.value_delta_cents)
    assert_equal 0, balance.on_hand_quantity
    assert_equal 0, balance.inventory_value_cents
    assert_equal 1, OutboxMessage.where(event_type: "inventory.sale_posted").count
    assert_empty Inventory::LedgerPairIntegrity.drifts(store_id: @store.id, product_variant_id: used_variant.id)
  end

  test "duplicate individual source effect is rejected" do
    _used_variant, unit = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax, name: "Used Duplicate")
    line = Pos::AddMerchandise.call(
      transaction: @transaction.reload,
      actor: @actor,
      expected_lock_version: @transaction.lock_version,
      identifier: unit.unit_identifier
    )
    PosTransaction.transaction do
      Inventory::PostSale.call(
        line: line,
        occurred_at: @occurred_at,
        business_date: @business_date,
        actor: @actor
      )
    end
    assert_raises(Inventory::PostSale::Error, ActiveRecord::RecordNotUnique) do
      PosTransaction.transaction do
        Inventory::PostSale.call(
          line: line,
          occurred_at: @occurred_at,
          business_date: @business_date,
          actor: @actor
        )
      end
    end
    assert unit.reload.removed?
    assert_equal 1, InventoryLedgerEntry.where(source_type: "PosTransactionLine", source_id: line.id).count
  end

  test "does not post a sale for non-inventory merchandise" do
    service = pos_sellable_variant(
      actor: @actor,
      tax_class: @tax,
      inventory_mode: "non_inventory",
      name: "Store Service"
    )
    line = Pos::AddMerchandise.call(
      transaction: @transaction.reload,
      actor: @actor,
      expected_lock_version: @transaction.lock_version,
      identifier: service.sku
    )

    error = assert_raises(Inventory::PostSale::Error) do
      PosTransaction.transaction do
        Inventory::PostSale.call(
          line: line,
          occurred_at: @occurred_at,
          business_date: @business_date,
          actor: @actor
        )
      end
    end
    assert_match(/not inventory-tracked/, error.message)
    assert_equal 0, InventoryLedgerEntry.where(source_type: "PosTransactionLine", source_id: line.id).count
    assert_equal 0, OutboxMessage.where(event_type: "inventory.sale_posted").count
  end

  private

  def open_stock(quantity, unit_cost_cents)
    Inventory::PostAdjustment.call(
      store: @store,
      product_variant: @variant,
      adjustment_reason: AdjustmentReason.find_by!(code: "opening_inventory"),
      quantity_delta: quantity,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      acquisition_unit_cost_cents: unit_cost_cents
    )
  end
end
