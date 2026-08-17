# frozen_string_literal: true

require "test_helper"

class Pos::ConcurrencyTest < ActiveSupport::TestCase
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
    @suffix = SecureRandom.hex(4)
    @tax = tax_class(code: "posc_#{@suffix}", name: "POS concurrency")
    StoreTaxes::Create.call(
      store: @store,
      actor: @actor,
      name: "State #{@suffix}",
      rate_percent: "5.000",
      calculation_order: 1,
      applies_by_tax_class_id: { @tax.id => true }
    )
    @variant = pos_sellable_variant(actor: @actor, tax_class: @tax)
  end

  teardown do
    conn = ActiveRecord::Base.connection
    tables = conn.tables - %w[schema_migrations ar_internal_metadata]
    conn.disable_referential_integrity do
      tables.each { |table| conn.execute("TRUNCATE TABLE #{conn.quote_table_name(table)} CASCADE") }
    end
  end

  test "concurrent completion of the same working transaction yields one receipt" do
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 5)
    ready = prepare_sale(register_number: 1, presented_cents: 2500)
    transaction_id = ready[:transaction].id
    lock_version = ready[:transaction].lock_version
    total = ready[:transaction].total_cents
    actor_id = @actor.id

    results = Array.new(2)
    errors = Array.new(2)
    threads = 2.times.map do |i|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          results[i] = Pos::CompleteTransaction.call(
            transaction: PosTransaction.find(transaction_id),
            actor: User.find(actor_id),
            operation_id: SecureRandom.uuid_v7,
            expected_lock_version: lock_version,
            expected_total_cents: total,
            amount_presented_cents: 2500
          )
        rescue StandardError => e
          errors[i] = e
        end
      end
    end
    threads.each { |thread| assert thread.join(30), "thread did not finish" }

    successes = results.compact
    failures = errors.compact
    assert_equal 1, successes.size, failures.map(&:message).inspect
    assert_equal 1, failures.size, successes.inspect
    transaction = PosTransaction.uncached { PosTransaction.find(transaction_id) }
    assert_equal "completed", transaction.status
    assert_equal 1, transaction.receipt_sequence
    assert_equal 1, OutboxMessage.uncached { OutboxMessage.where(event_type: "pos.transaction_completed").count }
    assert_equal 1, InventoryLedgerEntry.uncached { InventoryLedgerEntry.where(source_type: "PosTransactionLine").count }
  end

  test "two transactions racing the last unit leave the loser without a receipt" do
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 1)
    first = prepare_sale(register_number: 1, presented_cents: 2500)
    second = prepare_sale(register_number: 2, presented_cents: 2500)
    actor_id = @actor.id

    jobs = [ first, second ]
    results = Array.new(2)
    errors = Array.new(2)
    threads = jobs.each_with_index.map do |job, i|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          results[i] = Pos::CompleteTransaction.call(
            transaction: PosTransaction.find(job[:transaction].id),
            actor: User.find(actor_id),
            operation_id: SecureRandom.uuid_v7,
            expected_lock_version: job[:transaction].lock_version,
            expected_total_cents: job[:transaction].total_cents,
            amount_presented_cents: 2500
          )
        rescue StandardError => e
          errors[i] = e
        end
      end
    end
    threads.each { |thread| assert thread.join(30), "thread did not finish" }

    successes = results.compact
    failures = errors.compact
    assert_equal 1, successes.size
    assert_equal 1, failures.size
    assert_match(/insufficient|below zero/i, failures.first.message)

    winner = PosTransaction.uncached { successes.first.transaction.reload }
    loser_id = jobs.map { |job| job[:transaction].id } - [ winner.id ]
    loser = PosTransaction.uncached { PosTransaction.find(loser_id.first) }
    assert winner.completed?
    assert loser.working?
    assert_nil loser.receipt_sequence
    assert_equal 0, Register.uncached { loser.register.reload.receipt_sequence }
    assert_equal 1, OutboxMessage.uncached { OutboxMessage.where(event_type: "pos.transaction_completed").count }
    assert_equal 0, InventoryBalance.uncached { InventoryBalance.find_by!(store: @store, product_variant: @variant).on_hand_quantity }
  end

  test "start transaction versus close session cannot leave a working transaction on a closed session" do
    register = Register.create!(store: @store, register_number: 90, name: "Race")
    context = pos_open_context(store: @store, actor: @actor, register: register)
    session_id = context[:session].id
    lock_version = context[:session].lock_version
    actor_id = @actor.id

    start_result = nil
    close_result = nil
    start_error = nil
    close_error = nil
    threads = [
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          start_result = Pos::StartTransaction.call(session: PosSession.find(session_id), actor: User.find(actor_id))
        rescue StandardError => e
          start_error = e
        end
      end,
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          close_result = Pos::CloseSession.call(
            session: PosSession.find(session_id),
            actor: User.find(actor_id),
            expected_lock_version: lock_version,
            closing_count_cents: 0
          )
        rescue StandardError => e
          close_error = e
        end
      end
    ]
    threads.each { |thread| assert thread.join(30), "thread did not finish" }

    session = PosSession.uncached { PosSession.find(session_id) }
    working = PosTransaction.uncached { PosTransaction.where(pos_session_id: session_id, status: "working").count }
    refute session.closed? && working.positive?
    assert start_result || start_error
    assert close_result || close_error
  end

  test "open session versus finalize period never leaves an open session on a finalized period" do
    register = Register.create!(store: @store, register_number: 92, name: "Z race")
    period = Pos::OpenReportingPeriod.call(store: @store, register: register, actor: @actor)
    period_id = period.id
    lock_version = period.lock_version
    actor_id = @actor.id
    store_id = @store.id
    register_id = register.id

    open_result = nil
    finalize_result = nil
    open_error = nil
    finalize_error = nil
    threads = [
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          open_result = Pos::OpenSession.call(
            store: Store.find(store_id),
            register: Register.find(register_id),
            actor: User.find(actor_id),
            reporting_period: PosReportingPeriod.find(period_id),
            opening_float_cents: 0
          )
        rescue StandardError => e
          open_error = e
        end
      end,
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          finalize_result = Pos::FinalizeReportingPeriod.call(
            period: PosReportingPeriod.find(period_id),
            actor: User.find(actor_id),
            expected_lock_version: lock_version
          )
        rescue StandardError => e
          finalize_error = e
        end
      end
    ]
    threads.each { |thread| assert thread.join(30), "thread did not finish" }

    period = PosReportingPeriod.uncached { PosReportingPeriod.find(period_id) }
    open_sessions = PosSession.uncached { PosSession.where(reporting_period_id: period_id, status: "open").count }
    refute period.finalized? && open_sessions.positive?
    assert open_result || open_error
    assert finalize_result || finalize_error
  end

  test "concurrent lease begin for the same operation_id recovers without recursion" do
    register = Register.create!(store: @store, register_number: 91, name: "Lease")
    operation_id = SecureRandom.uuid_v7
    payload = {
      "transaction_id" => SecureRandom.uuid_v7,
      "operation_id" => operation_id,
      "expected_lock_version" => 0,
      "expected_total_cents" => 100,
      "amount_presented_cents" => 100
    }
    results = Array.new(2)
    errors = Array.new(2)
    threads = 2.times.map do |i|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          results[i] = Pos::OperationLease.begin!(
            register_id: register.id,
            operation_id: operation_id,
            command_payload: payload,
            store_id: @store.id,
            pos_transaction_id: nil
          )
        rescue StandardError => e
          errors[i] = e
        end
      end
    end
    threads.each { |thread| assert thread.join(30), "thread did not finish" }

    assert errors.compact.none? { |error| error.is_a?(SystemStackError) }, errors.compact.map(&:class).inspect
    assert_equal 1, PosOperation.uncached { PosOperation.where(id: operation_id).count }
    successes = results.compact
    assert successes.any?
    assert_equal [ operation_id ], successes.map { |result| result.operation.id }.uniq
  end

  private

  def prepare_sale(register_number:, presented_cents:)
    register = Register.create!(store: @store, register_number: register_number, name: "Lane #{register_number}")
    context = pos_open_context(store: @store, actor: @actor, register: register)
    transaction = Pos::StartTransaction.call(session: context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku
    )
    transaction.reload
    Pos::TenderCash.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: presented_cents
    )
    { context: context, transaction: transaction.reload }
  end
end
