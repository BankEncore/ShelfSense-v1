# frozen_string_literal: true

require "test_helper"

class Inventory::ConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @actor = User.find_by(username: "admin")
    unless @actor
      bootstrap = bootstrap!
      @actor = bootstrap[:administrator]
    end
    @store = Store.find_by!(code: "main")
    Inventory::AdjustmentReasons.seed!
    Authorization::PermissionCatalog.seed!(granted_by: @actor)
    @opening = AdjustmentReason.find_by!(code: "opening_inventory")
    @suffix = SecureRandom.hex(4)
    @tax = tax_class(code: "c_#{@suffix}")
    @department = department(code: "c_#{@suffix}")
    @klass = merchandise_class(
      code: "c_#{@suffix}",
      department: @department,
      pricing_method: "fixed"
    )
    @product = Products::Create.call(
      attributes: { name: "Concurrency #{@suffix}", status: "active" },
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
  end

  teardown do
    conn = ActiveRecord::Base.connection
    tables = conn.tables - %w[schema_migrations ar_internal_metadata]
    conn.disable_referential_integrity do
      tables.each { |table| conn.execute("TRUNCATE TABLE #{conn.quote_table_name(table)} CASCADE") }
    end
  end

  test "concurrent first-balance create ends with one balance and summed quantity" do
    store_id = @store.id
    variant_id = @variant.id
    actor_id = @actor.id
    reason_id = @opening.id
    results = Array.new(2)
    errors = Array.new(2)
    threads = 2.times.map do |i|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          results[i] = Inventory::PostAdjustment.call(
            store: Store.find(store_id),
            product_variant: ProductVariant.find(variant_id),
            adjustment_reason: AdjustmentReason.find(reason_id),
            quantity_delta: 1,
            actor: User.find(actor_id),
            source_id: SecureRandom.uuid_v7,
            idempotency_key: SecureRandom.uuid_v7,
            acquisition_unit_cost_cents: 100
          )
        rescue StandardError => e
          errors[i] = e
        end
      end
    end
    threads.each { |thread| assert thread.join(20), "thread did not finish" }
    assert_nil errors[0], errors[0]&.full_message
    assert_nil errors[1], errors[1]&.full_message
    assert results[0]
    assert results[1]
    assert_not_equal results[0].id, results[1].id

    balances = InventoryBalance.where(store_id: store_id, product_variant_id: variant_id)
    assert_equal 1, balances.count
    assert_equal 2, balances.first.on_hand_quantity
    assert_equal 200, balances.first.inventory_value_cents
  end

  test "reversal race reports already reversed" do
    original = Inventory::PostAdjustment.call(
      store: @store,
      product_variant: @variant,
      adjustment_reason: @opening,
      quantity_delta: 3,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      acquisition_unit_cost_cents: 100
    )

    original_id = original.id
    actor_id = @actor.id
    results = Array.new(2)
    errors = Array.new(2)
    threads = 2.times.map do |i|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          results[i] = Inventory::ReverseAdjustment.call(
            adjustment: InventoryAdjustment.find(original_id),
            actor: User.find(actor_id),
            source_id: SecureRandom.uuid_v7,
            idempotency_key: SecureRandom.uuid_v7,
            notes: "concurrent reverse #{i}"
          )
        rescue StandardError => e
          errors[i] = e
        end
      end
    end
    threads.each { |thread| assert thread.join(20), "thread did not finish" }

    successes = results.compact
    failures = errors.compact
    assert_equal 1, successes.size
    assert_equal 1, failures.size
    assert_match(/already reversed/i, failures.first.message)
    assert original.reload.reversed?
    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 0, balance.on_hand_quantity
    assert_equal 0, balance.inventory_value_cents
  end

  test "concurrent begin! of a new key yields one in_flight and one still-in-flight error" do
    source_id = SecureRandom.uuid_v7
    key = SecureRandom.uuid_v7
    payload = { n: 1 }

    results = Array.new(2)
    errors = Array.new(2)
    threads = 2.times.map do |i|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          results[i] = Idempotency::OperationService.begin!(
            source_id: source_id,
            operation_type: "post_inventory_adjustment",
            idempotency_key: key,
            payload: payload
          )
        rescue StandardError => e
          errors[i] = e
        end
      end
    end
    threads.each { |thread| assert thread.join(20), "thread did not finish" }

    successes = results.compact
    failures = errors.compact
    assert_equal 1, successes.size
    assert_equal 1, failures.size
    assert_not successes.first.replayed
    assert_match(/still in flight/i, failures.first.message)
    assert_equal 1, IdempotencyOperation.where(source_id: source_id, idempotency_key: key).count
  end
end
