# frozen_string_literal: true

require "test_helper"

class InventoryReturnValuationTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    @tax = tax_class(code: "return_val_tax")
    @variant = pos_sellable_variant(actor: @actor, tax_class: @tax)
  end

  test "quantity on-hand uses current moving average without capping at current value" do
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 2, unit_cost_cents: 50)
    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)

    result = Inventory::ReturnValuation.call(
      store: @store,
      variant: @variant,
      quantity: 3,
      balance: balance
    )

    assert_equal 150, result.incoming_value_cents
    assert_equal "current_moving_average", result.basis
  end

  test "quantity on-hand zero uses only the latest prior moving average" do
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 5, unit_cost_cents: 100)
    sell_all_quantity!(5)
    latest = InventoryValuationEntry.where(store: @store, product_variant: @variant)
                                    .order(occurred_at: :desc, id: :desc)
                                    .first
    assert_equal 0, InventoryBalance.find_by!(store: @store, product_variant: @variant).on_hand_quantity
    assert_equal 5, latest.calculation_metadata["prior_quantity"]
    assert_equal 500, latest.calculation_metadata["prior_value_cents"]

    result = Inventory::ReturnValuation.call(store: @store, variant: @variant, quantity: 2)
    assert_equal 200, result.incoming_value_cents
    assert_equal "latest_prior_moving_average", result.basis
  end

  test "quantity without a prior basis is rejected" do
    error = assert_raises(Inventory::ReturnValuation::Error) do
      Inventory::ReturnValuation.call(store: @store, variant: @variant, quantity: 1)
    end
    assert_match(/no defensible inventory valuation basis/, error.message)
  end

  test "used unit restores carrying value independent of a later price" do
    _used_variant, unit = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax, unit_cost_cents: 500)
    unit.update_columns(lifecycle_state: "removed", removed_at: Time.current)

    result = Inventory::ReturnValuation.call(
      store: @store,
      variant: unit.product_variant,
      quantity: 1,
      inventory_unit: unit
    )
    assert_equal 500, result.incoming_value_cents
    assert_equal "unit_carrying_value", result.basis
  end

  private

  def sell_all_quantity!(quantity)
    StoreTaxes::Create.call(
      store: @store,
      actor: @actor,
      name: "State",
      rate_percent: "0.000",
      calculation_order: 1,
      applies_by_tax_class_id: { @tax.id => false }
    )
    context = pos_open_context(store: @store, actor: @actor)
    Pos::TenderTypes.seed!
    transaction = Pos::StartTransaction.call(session: context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku,
      quantity: quantity
    )
    transaction.reload
    Pos::TenderCash.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: [ transaction.total_cents, 1 ].max
    )
    Pos::CompleteTransaction.call(
      transaction: transaction.reload,
      actor: @actor,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents,
      expected_signed_net_cents: transaction.signed_net_cents
    )
  end
end
