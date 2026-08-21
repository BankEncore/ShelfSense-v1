# frozen_string_literal: true

require "test_helper"

class InventoryPostAdjustmentTest < ActiveSupport::TestCase
  include Phase2Fixtures

  setup do
    @actor = actor_user
    @store = Store.find_by!(code: "main")
    Inventory::AdjustmentReasons.seed!
    Authorization::PermissionCatalog.seed!(granted_by: @actor)

    @tax = tax_class(code: "inv_tax")
    @department = department(code: "inv_dept")
    @klass = merchandise_class(
      code: "inv_std",
      department: @department,
      pricing_method: "fixed"
    )
    @product = Products::Create.call(
      attributes: { name: "Widget", status: "active" },
      actor: @actor
    )
    @variant = ProductVariants::Create.call(
      product: @product,
      attributes: {
        variant_type: "standard",
        status: "active",
        merchandise_class_id: @klass.id,
        regular_price_cents: 1999
      },
      actor: @actor
    )
    @opening = AdjustmentReason.find_by!(code: "opening_inventory")
    @shrinkage = AdjustmentReason.find_by!(code: "shrinkage")
  end

  test "opening quantity inventory establishes quantity and value" do
    adjustment = post_qty(10, 100)
    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 10, balance.on_hand_quantity
    assert_equal 1_000, balance.inventory_value_cents
    assert_equal 1, InventoryLedgerEntry.where(source_id: adjustment.id).count
    assert_equal 1, OutboxMessage.where(event_type: "inventory.adjustment_posted").count
  end

  test "partial depletion uses half-up proportional value" do
    post_qty(3, 100)
    post_qty(-1, nil, reason: @shrinkage)
    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 2, balance.on_hand_quantity
    assert_equal 200, balance.inventory_value_cents
  end

  test "final depletion clears value exactly" do
    post_qty(3, 100)
    post_qty(-1, nil, reason: @shrinkage)
    post_qty(-2, nil, reason: @shrinkage)
    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 0, balance.on_hand_quantity
    assert_equal 0, balance.inventory_value_cents
  end

  test "rejects negative on-hand" do
    post_qty(1, 100)
    error = assert_raises(Inventory::PostAdjustment::Error) { post_qty(-2, nil, reason: @shrinkage) }
    assert_match(/below zero|insufficient/i, error.message)
  end

  test "idempotent retry returns same adjustment" do
    key = SecureRandom.uuid_v7
    source = SecureRandom.uuid_v7
    first = post_qty(2, 50, key: key, source: source)
    second = post_qty(2, 50, key: key, source: source)
    assert_equal first.id, second.id
    assert_equal 1, InventoryAdjustment.where(product_variant: @variant).count
  end

  test "payload mismatch is an error" do
    key = SecureRandom.uuid_v7
    source = SecureRandom.uuid_v7
    post_qty(2, 50, key: key, source: source)
    assert_raises(Idempotency::OperationService::PayloadMismatchError) do
      post_qty(3, 50, key: key, source: source)
    end
  end

  test "exact reversal negates stored effects" do
    original = post_qty(5, 200)
    reversal = Inventory::ReverseAdjustment.call(
      adjustment: original,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      notes: "mistake"
    )
    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 0, balance.on_hand_quantity
    assert_equal 0, balance.inventory_value_cents
    assert original.reload.reversed?
    assert_equal(-original.quantity_delta, reversal.quantity_delta)
  end

  test "second reversal is rejected" do
    original = post_qty(5, 200)
    Inventory::ReverseAdjustment.call(
      adjustment: original,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      notes: "mistake"
    )
    error = assert_raises(Inventory::ReverseAdjustment::Error) do
      Inventory::ReverseAdjustment.call(
        adjustment: original.reload,
        actor: @actor,
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7,
        notes: "again"
      )
    end
    assert_match(/already reversed/i, error.message)
  end

  test "individual acquisition and removal" do
    used_klass = merchandise_class(
      code: "inv_used",
      used_merchandise_allowed: true,
      department: @department,
            pricing_method: "fixed"
    )
    condition = merchandise_condition(code: "good")
    used = ProductVariants::Create.call(
      product: @product,
      attributes: {
        variant_type: "used",
        status: "active",
        merchandise_class_id: used_klass.id,
        merchandise_condition_id: condition.id,
        regular_price_cents: 1200
      },
      actor: @actor
    )

    acquisition = Inventory::PostAdjustment.call(
      store: @store,
      product_variant: used,
      adjustment_reason: @opening,
      quantity_delta: 1,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      acquisition_unit_cost_cents: 500,
      regular_price_cents: 900
    )
    unit = acquisition.inventory_unit
    assert unit.on_hand?
    assert_equal 900, unit.regular_price_cents
    assert unit.unit_identifier.start_with?("220")

    Inventory::PostAdjustment.call(
      store: @store,
      product_variant: used,
      adjustment_reason: @shrinkage,
      quantity_delta: -1,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      unit_identifier: unit.unit_identifier
    )
    assert unit.reload.removed?
    balance = InventoryBalance.find_by!(store: @store, product_variant: used)
    assert_equal 0, balance.on_hand_quantity
    assert_equal 0, balance.inventory_value_cents
  end

  test "individual removal rejects missing unit identifier" do
    used_klass = merchandise_class(
      code: "inv_used_miss",
      used_merchandise_allowed: true,
      department: @department,
            pricing_method: "fixed"
    )
    condition = merchandise_condition(code: "good")
    used = ProductVariants::Create.call(
      product: @product,
      attributes: {
        variant_type: "used",
        status: "active",
        merchandise_class_id: used_klass.id,
        merchandise_condition_id: condition.id,
        regular_price_cents: 1200
      },
      actor: @actor
    )
    Inventory::PostAdjustment.call(
      store: @store,
      product_variant: used,
      adjustment_reason: @opening,
      quantity_delta: 1,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      acquisition_unit_cost_cents: 500
    )

    error = assert_raises(Inventory::PostAdjustment::Error) do
      Inventory::PostAdjustment.call(
        store: @store,
        product_variant: used,
        adjustment_reason: @shrinkage,
        quantity_delta: -1,
        actor: @actor,
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7
      )
    end
    assert_match(/unit identifier is required/i, error.message)
  end

  test "allow_below_zero and unknown policies are rejected" do
    error = assert_raises(Inventory::PostAdjustment::Error) do
      Inventory::PostAdjustment.call(
        store: @store,
        product_variant: @variant,
        adjustment_reason: @opening,
        quantity_delta: 1,
        actor: @actor,
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7,
        acquisition_unit_cost_cents: 100,
        negative_stock_policy: "allow_below_zero"
      )
    end
    assert_match(/unsupported negative stock policy/i, error.message)

    error = assert_raises(Inventory::PostAdjustment::Error) do
      Inventory::PostAdjustment.call(
        store: @store,
        product_variant: @variant,
        adjustment_reason: @opening,
        quantity_delta: 1,
        actor: @actor,
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7,
        acquisition_unit_cost_cents: 100,
        negative_stock_policy: "unknown_policy"
      )
    end
    assert_match(/unsupported negative stock policy/i, error.message)
  end

  test "database check rejects negative balances" do
    post_qty(1, 100)
    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_raises(ActiveRecord::StatementInvalid) do
      InventoryBalance.transaction(requires_new: true) do
        balance.update_columns(on_hand_quantity: -1)
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      InventoryBalance.transaction(requires_new: true) do
        balance.update_columns(inventory_value_cents: -1)
      end
    end
    balance.reload
    balance.on_hand_quantity = -1
    assert_not balance.valid?
  end

  test "unauthorized occurred_at is ignored and posts as now" do
    supplied = Time.zone.parse("2026-01-15 12:00:00")
    freeze_time = Time.zone.parse("2026-08-12 15:30:00")
    travel_to freeze_time do
      adjustment = Inventory::PostAdjustment.call(
        store: @store,
        product_variant: @variant,
        adjustment_reason: @opening,
        quantity_delta: 1,
        actor: @actor,
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7,
        acquisition_unit_cost_cents: 100,
        occurred_at: supplied,
        allow_backdate: false
      )
      assert_in_delta freeze_time, adjustment.occurred_at, 1
      assert_equal BusinessDate.for_store(@store, at: freeze_time), adjustment.business_date
    end
  end

  test "authorized past occurred_at is accepted and derives business_date" do
    past = Time.zone.parse("2026-08-01 10:00:00")
    adjustment = Inventory::PostAdjustment.call(
      store: @store,
      product_variant: @variant,
      adjustment_reason: @opening,
      quantity_delta: 1,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      acquisition_unit_cost_cents: 100,
      occurred_at: past,
      allow_backdate: true
    )
    assert_in_delta past, adjustment.occurred_at, 1
    assert_equal BusinessDate.for_store(@store, at: past), adjustment.business_date
  end

  test "future occurred_at is rejected when backdating is allowed" do
    error = assert_raises(Inventory::PostAdjustment::Error) do
      Inventory::PostAdjustment.call(
        store: @store,
        product_variant: @variant,
        adjustment_reason: @opening,
        quantity_delta: 1,
        actor: @actor,
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7,
        acquisition_unit_cost_cents: 100,
        occurred_at: 1.hour.from_now,
        allow_backdate: true
      )
    end
    assert_match(/future/i, error.message)
  end

  test "unexpected error marks idempotency operation failed" do
    boom = Class.new(Inventory::PostAdjustment) do
      def lock_or_create_balance!
        raise "boom"
      end
    end
    key = SecureRandom.uuid_v7
    source = SecureRandom.uuid_v7
    assert_raises(RuntimeError) do
      boom.call(
        store: @store,
        product_variant: @variant,
        adjustment_reason: @opening,
        quantity_delta: 1,
        actor: @actor,
        source_id: source,
        idempotency_key: key,
        acquisition_unit_cost_cents: 100
      )
    end
    operation = IdempotencyOperation.find_by!(
      source_id: source,
      operation_type: "post_inventory_adjustment",
      idempotency_key: key
    )
    assert_equal "failed", operation.status
    assert_equal "boom", operation.error_message
  end

  test "supplied unit identifier is normalized before reserve" do
    used = create_used_variant("inv_used_norm")
    identifier = Identifiers::Ean13.complete("220", "999999001")
    formatted = "#{identifier[0, 3]}-#{identifier[3, 4]}-#{identifier[7, 5]}-#{identifier[12]}"

    acquisition = Inventory::PostAdjustment.call(
      store: @store,
      product_variant: used,
      adjustment_reason: @opening,
      quantity_delta: 1,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      acquisition_unit_cost_cents: 500,
      unit_identifier: formatted
    )
    assert_equal identifier, acquisition.inventory_unit.unit_identifier
    assert Identifiers::Registry.find_active(identifier)
  end

  test "invalid unit identifier check digit is rejected" do
    used = create_used_variant("inv_used_bad_cd")
    error = assert_raises(Inventory::PostAdjustment::Error) do
      Inventory::PostAdjustment.call(
        store: @store,
        product_variant: used,
        adjustment_reason: @opening,
        quantity_delta: 1,
        actor: @actor,
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7,
        acquisition_unit_cost_cents: 500,
        unit_identifier: "2200000000001"
      )
    end
    assert_match(/check digit/i, error.message)
  end

  test "non-220 unit identifier is rejected" do
    used = create_used_variant("inv_used_isbn")
    error = assert_raises(Inventory::PostAdjustment::Error) do
      Inventory::PostAdjustment.call(
        store: @store,
        product_variant: used,
        adjustment_reason: @opening,
        quantity_delta: 1,
        actor: @actor,
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7,
        acquisition_unit_cost_cents: 500,
        unit_identifier: external_isbn13
      )
    end
    assert_match(/220 namespace/i, error.message)
  end

  test "database check rejects zero quantity with residual value" do
    post_qty(1, 100)
    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_raises(ActiveRecord::StatementInvalid) do
      InventoryBalance.transaction(requires_new: true) do
        balance.update_columns(on_hand_quantity: 0, inventory_value_cents: 500)
      end
    end
    balance.reload
    balance.on_hand_quantity = 0
    balance.inventory_value_cents = 500
    assert_not balance.valid?
    assert_includes balance.errors[:inventory_value_cents], "must be zero when on-hand quantity is zero"
  end

  private

  def post_qty(delta, cost_cents, reason: @opening, key: SecureRandom.uuid_v7, source: SecureRandom.uuid_v7)
    Inventory::PostAdjustment.call(
      store: @store,
      product_variant: @variant,
      adjustment_reason: reason,
      quantity_delta: delta,
      actor: @actor,
      source_id: source,
      idempotency_key: key,
      acquisition_unit_cost_cents: cost_cents
    )
  end

  def create_used_variant(class_code)
    used_klass = merchandise_class(
      code: class_code,
      used_merchandise_allowed: true,
      department: @department,
            pricing_method: "fixed"
    )
    condition = MerchandiseCondition.find_by(code: "good") || merchandise_condition(code: "good")
    ProductVariants::Create.call(
      product: @product,
      attributes: {
        variant_type: "used",
        status: "active",
        merchandise_class_id: used_klass.id,
        merchandise_condition_id: condition.id,
        regular_price_cents: 1200
      },
      actor: @actor
    )
  end
end
