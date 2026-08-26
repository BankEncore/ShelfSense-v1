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
            expected_total_cents: total
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
            expected_total_cents: job[:transaction].total_cents
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
          close_result = pos_close_session!(
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
    successes = [ open_result, finalize_result ].compact
    failures = [ open_error, finalize_error ].compact

    refute period.finalized? && open_sessions.positive?
    assert_equal 1, successes.size, "exactly one of OpenSession or FinalizeReportingPeriod must succeed"
    assert_equal 1, failures.size, "the other command must reject"
    if open_result
      assert period.open?
      assert_equal 1, open_sessions
    else
      assert period.finalized?
      assert_equal 0, open_sessions
    end
  end

  test "concurrent lease begin for the same operation_id recovers without recursion" do
    register = Register.create!(store: @store, register_number: 91, name: "Lease")
    operation_id = SecureRandom.uuid_v7
    payload = {
      "transaction_id" => SecureRandom.uuid_v7,
      "operation_id" => operation_id,
      "expected_lock_version" => 0,
      "expected_total_cents" => 100
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

  test "concurrent resume or start yields one working transaction" do
    register = Register.create!(store: @store, register_number: 93, name: "Resume")
    context = pos_open_context(store: @store, actor: @actor, register: register)
    session_id = context[:session].id
    actor_id = @actor.id

    results = Array.new(2)
    errors = Array.new(2)
    threads = 2.times.map do |i|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          results[i] = Pos::ResumeOrStartTransaction.call(
            session: PosSession.find(session_id),
            actor: User.find(actor_id)
          )
        rescue StandardError => e
          errors[i] = e
        end
      end
    end
    threads.each { |thread| assert thread.join(30), "thread did not finish" }

    assert_equal [], errors.compact.map(&:message)
    ids = results.compact.map(&:id).uniq
    assert_equal 1, ids.size
    assert_equal 1, PosTransaction.uncached {
      PosTransaction.where(pos_session_id: session_id, status: "working").count
    }
  end

  test "concurrent adds of the same unit from two registers leave one working line" do
    _used_variant, unit = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax, name: "Race Used")
    first = prepare_empty_sale(register_number: 21)
    second = prepare_empty_sale(register_number: 22)
    actor_id = @actor.id
    unit_identifier = unit.unit_identifier

    ready = Queue.new
    go = Queue.new
    results = Array.new(2)
    errors = Array.new(2)
    jobs = [ first, second ]
    threads = jobs.each_with_index.map do |job, i|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          go.pop
          results[i] = Pos::AddMerchandise.call(
            transaction: PosTransaction.find(job[:transaction].id),
            actor: User.find(actor_id),
            expected_lock_version: job[:transaction].lock_version,
            identifier: unit_identifier
          )
        rescue StandardError => e
          errors[i] = e
        end
      end
    end
    2.times { ready.pop }
    2.times { go << true }
    threads.each { |thread| assert thread.join(30), "thread did not finish" }

    successes = results.compact
    failures = errors.compact
    assert_equal 1, successes.size, failures.map(&:message).inspect
    assert_equal 1, failures.size, successes.inspect
    assert_match(/already on a working transaction/, failures.first.message)
    assert_equal 1, PosTransactionLine.uncached {
      PosTransactionLine.where(inventory_unit_id: unit.id).count
    }
    working_owners = PosTransactionLine.uncached {
      PosTransactionLine.joins(:pos_transaction)
                        .where(inventory_unit_id: unit.id, pos_transactions: { status: "working" })
                        .count
    }
    assert_equal 1, working_owners
  end

  test "concurrent completion and shrinkage of the same unit do not deadlock" do
    _used_variant, unit = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax, name: "Deadlock Used")
    ready_sale = prepare_unit_sale(register_number: 23, unit: unit, presented_cents: 2500)
    actor_id = @actor.id
    store_id = @store.id
    variant_id = unit.product_variant_id
    unit_identifier = unit.unit_identifier
    shrinkage_id = AdjustmentReason.find_by!(code: "shrinkage").id

    ready = Queue.new
    go = Queue.new
    complete_result = nil
    adjustment_result = nil
    complete_error = nil
    adjustment_error = nil
    threads = [
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          go.pop
          complete_result = Pos::CompleteTransaction.call(
            transaction: PosTransaction.find(ready_sale[:transaction].id),
            actor: User.find(actor_id),
            operation_id: SecureRandom.uuid_v7,
            expected_lock_version: ready_sale[:transaction].lock_version,
            expected_total_cents: ready_sale[:transaction].total_cents
          )
        rescue StandardError => e
          complete_error = e
        end
      end,
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          go.pop
          adjustment_result = Inventory::PostAdjustment.call(
            store: Store.find(store_id),
            product_variant: ProductVariant.find(variant_id),
            adjustment_reason: AdjustmentReason.find(shrinkage_id),
            quantity_delta: -1,
            actor: User.find(actor_id),
            source_id: SecureRandom.uuid_v7,
            idempotency_key: SecureRandom.uuid_v7,
            unit_identifier: unit_identifier
          )
        rescue StandardError => e
          adjustment_error = e
        end
      end
    ]
    2.times { ready.pop }
    2.times { go << true }
    threads.each { |thread| assert thread.join(30), "thread did not finish" }

    [ complete_error, adjustment_error ].compact.each do |error|
      refute_match(/deadlock/i, error.message)
    end

    successes = [ complete_result, adjustment_result ].compact
    failures = [ complete_error, adjustment_error ].compact
    assert_equal 1, successes.size, failures.map(&:message).inspect
    assert_equal 1, failures.size

    unit = InventoryUnit.uncached { InventoryUnit.find(unit.id) }
    assert unit.removed?
    sale_count = InventoryLedgerEntry.uncached {
      InventoryLedgerEntry.where(source_type: "PosTransactionLine", inventory_unit_id: unit.id).count
    }
    adjustment_count = InventoryLedgerEntry.uncached {
      InventoryLedgerEntry.where(source_type: "InventoryAdjustment", inventory_unit_id: unit.id, entry_type: "adjustment")
                          .where("quantity_delta < 0").count
    }
    transaction = PosTransaction.uncached { PosTransaction.find(ready_sale[:transaction].id) }
    if complete_result
      assert transaction.completed?
      assert_equal 1, sale_count
      assert_equal 0, adjustment_count
    else
      assert transaction.working?
      assert_nil transaction.receipt_sequence
      assert_equal 0, sale_count
      assert_equal 1, adjustment_count
    end
  end

  test "two registers racing the last linked return quantity yield one completion" do
    Pos::TenderTypes.seed!
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 1)
    original_ready = prepare_sale(register_number: 11, presented_cents: 2500)
    original = Pos::CompleteTransaction.call(
      transaction: original_ready[:transaction],
      actor: @actor,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: original_ready[:transaction].lock_version,
      expected_total_cents: original_ready[:transaction].total_cents
    ).transaction
    original_line = original.pos_transaction_lines.first
    original_line_id = original_line.id
    actor_id = @actor.id

    first = prepare_linked_return(register_number: 12, original_line: original_line)
    second = prepare_linked_return(register_number: 13, original_line: original_line)
    jobs = [ first, second ]
    ready = Queue.new
    go = Queue.new
    results = Array.new(2)
    errors = Array.new(2)
    threads = jobs.each_with_index.map do |job, i|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          go.pop
          transaction = PosTransaction.find(job[:transaction].id)
          results[i] = Pos::CompleteTransaction.call(
            transaction: transaction,
            actor: User.find(actor_id),
            operation_id: SecureRandom.uuid_v7,
            expected_lock_version: transaction.lock_version,
            expected_total_cents: transaction.total_cents,
            expected_signed_net_cents: transaction.signed_net_cents
          )
        rescue StandardError => e
          errors[i] = e
        end
      end
    end
    2.times { ready.pop }
    2.times { go << true }
    threads.each { |thread| assert thread.join(30), "thread did not finish" }

    successes = results.compact
    failures = errors.compact
    assert_equal 1, successes.size, failures.map(&:message).inspect
    assert_equal 1, failures.size, successes.inspect
    assert_match(/remaining quantity|stale lock/i, failures.first.message)

    winner = successes.first.transaction
    assert winner.completed?
    loser_id = jobs.map { |job| job[:transaction].id } - [ winner.id ]
    loser = PosTransaction.uncached { PosTransaction.find(loser_id.first) }
    assert loser.working?
    assert_nil loser.receipt_sequence
    assert_equal 1, OutboxMessage.uncached {
      OutboxMessage.where(event_type: "inventory.return_posted").count
    }
    remaining = PosTransactionLine.uncached {
      Pos::Returnability.remaining_quantity(PosTransactionLine.find(original_line_id))
    }
    assert_equal 0, remaining
  end

  test "two registers cannot concurrently claim the same removed used unit" do
    Pos::TenderTypes.seed!
    _used_variant, unit = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax)
    sale = prepare_unit_sale(register_number: 21, unit: unit, presented_cents: 2500)
    Pos::CompleteTransaction.call(
      transaction: sale[:transaction],
      actor: @actor,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: sale[:transaction].lock_version,
      expected_total_cents: sale[:transaction].total_cents,
      expected_signed_net_cents: sale[:transaction].signed_net_cents
    )
    assert unit.reload.removed?

    first = prepare_empty_sale(register_number: 22)
    second = prepare_empty_sale(register_number: 23)
    jobs = [
      { transaction_id: first[:transaction].id, lock_version: first[:transaction].lock_version },
      { transaction_id: second[:transaction].id, lock_version: second[:transaction].lock_version }
    ]
    unit_id = unit.id
    identifier = unit.unit_identifier
    actor_id = @actor.id
    ready = Queue.new
    go = Queue.new
    results = Array.new(2)
    errors = Array.new(2)
    threads = jobs.each_with_index.map do |job, i|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          go.pop
          results[i] = Pos::ExecuteUnlinkedReturn.call(
            transaction: PosTransaction.find(job[:transaction_id]),
            actor: User.find(actor_id),
            expected_lock_version: job[:lock_version],
            identifier: identifier,
            quantity: 1,
            reason_code: "changed_mind",
            requested_return_unit_price_cents: 1200
          )
        rescue StandardError => e
          errors[i] = e
        end
      end
    end
    2.times { ready.pop }
    2.times { go << true }
    threads.each { |thread| assert thread.join(30), "thread did not finish" }

    successes = results.compact
    failures = errors.compact
    assert_equal 1, successes.size, failures.map(&:message).inspect
    assert_equal 1, failures.size, successes.inspect
    assert_match(/already on a working return|stale lock/i, failures.first.message)

    working_lines = PosTransactionLine.uncached {
      PosTransactionLine.joins(:pos_transaction).where(
        inventory_unit_id: unit_id,
        pos_transactions: { status: "working" }
      ).to_a
    }
    assert_equal 1, working_lines.size
    assert_equal successes.first.id, working_lines.first.id
    assert_equal 1, PosControlledAction.uncached {
      PosControlledAction.where(action_type: "unlinked_return", pos_transaction_line_id: working_lines.first.id).count
    }
    assert InventoryUnit.uncached { InventoryUnit.find(unit_id).removed? }
  end

  test "sale versus unlinked restore of the same used unit leaves one valid unit state" do
    Pos::TenderTypes.seed!
    _used_variant, unit = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax, name: "Sale vs unlinked")
    sale = prepare_unit_sale(register_number: 41, unit: unit, presented_cents: 2500)
    Pos::CompleteTransaction.call(
      transaction: sale[:transaction],
      actor: @actor,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: sale[:transaction].lock_version,
      expected_total_cents: sale[:transaction].total_cents,
      expected_signed_net_cents: sale[:transaction].signed_net_cents
    )
    assert unit.reload.removed?

    unlinked = prepare_unlinked_return(register_number: 42, unit: unit)
    sale_job = prepare_empty_sale(register_number: 43)
    actor_id = @actor.id
    unit_id = unit.id
    identifier = unit.unit_identifier
    unlinked_id = unlinked[:transaction].id
    unlinked_lock = unlinked[:transaction].lock_version
    unlinked_total = unlinked[:transaction].total_cents
    unlinked_net = unlinked[:transaction].signed_net_cents
    sale_id = sale_job[:transaction].id
    sale_lock = sale_job[:transaction].lock_version
    ready = Queue.new
    go = Queue.new
    unlinked_result = nil
    sale_result = nil
    unlinked_error = nil
    sale_error = nil

    threads = [
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          go.pop
          unlinked_result = Pos::CompleteTransaction.call(
            transaction: PosTransaction.find(unlinked_id),
            actor: User.find(actor_id),
            operation_id: SecureRandom.uuid_v7,
            expected_lock_version: unlinked_lock,
            expected_total_cents: unlinked_total,
            expected_signed_net_cents: unlinked_net
          )
        rescue StandardError => e
          unlinked_error = e
        end
      end,
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          go.pop
          transaction = PosTransaction.find(sale_id)
          Pos::AddMerchandise.call(
            transaction: transaction,
            actor: User.find(actor_id),
            expected_lock_version: sale_lock,
            identifier: identifier
          )
          transaction.reload
          Pos::TenderCash.call(
            transaction: transaction,
            actor: User.find(actor_id),
            expected_lock_version: transaction.lock_version,
            amount_presented_cents: transaction.total_cents
          )
          sale_result = Pos::CompleteTransaction.call(
            transaction: transaction.reload,
            actor: User.find(actor_id),
            operation_id: SecureRandom.uuid_v7,
            expected_lock_version: transaction.lock_version,
            expected_total_cents: transaction.total_cents,
            expected_signed_net_cents: transaction.signed_net_cents
          )
        rescue StandardError => e
          sale_error = e
        end
      end
    ]
    2.times { ready.pop }
    2.times { go << true }
    threads.each { |thread| assert thread.join(30), "thread did not finish" }

    assert unlinked_result || unlinked_error
    assert sale_result || sale_error
    unit = InventoryUnit.uncached { InventoryUnit.find(unit_id) }
    restores = InventoryLedgerEntry.uncached {
      InventoryLedgerEntry.where(
        inventory_unit_id: unit_id,
        source_type: "PosTransactionLine",
        entry_type: "return"
      ).count
    }
    assert_equal 1, restores
    assert unit.on_hand? || unit.removed?
    if unit.removed?
      assert sale_result
      assert unlinked_result
    else
      assert unlinked_result
      assert_nil sale_result
    end
    assert_empty Inventory::LedgerPairIntegrity.drifts(store_id: @store.id)
  end

  test "linked versus unlinked restore of the same used unit yields one on-hand unit" do
    Pos::TenderTypes.seed!
    _used_variant, unit = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax, name: "Linked vs unlinked")
    sale = prepare_unit_sale(register_number: 31, unit: unit, presented_cents: 2500)
    original = Pos::CompleteTransaction.call(
      transaction: sale[:transaction],
      actor: @actor,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: sale[:transaction].lock_version,
      expected_total_cents: sale[:transaction].total_cents,
      expected_signed_net_cents: sale[:transaction].signed_net_cents
    ).transaction
    original_line = original.pos_transaction_lines.first
    assert unit.reload.removed?

    unlinked = prepare_unlinked_return(register_number: 32, unit: unit)
    linked = prepare_linked_return(register_number: 33, original_line: original_line)
    jobs = [ unlinked, linked ]
    actor_id = @actor.id
    unit_id = unit.id
    ready = Queue.new
    go = Queue.new
    results = Array.new(2)
    errors = Array.new(2)
    threads = jobs.each_with_index.map do |job, i|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          go.pop
          transaction = PosTransaction.find(job[:transaction].id)
          results[i] = Pos::CompleteTransaction.call(
            transaction: transaction,
            actor: User.find(actor_id),
            operation_id: SecureRandom.uuid_v7,
            expected_lock_version: transaction.lock_version,
            expected_total_cents: transaction.total_cents,
            expected_signed_net_cents: transaction.signed_net_cents
          )
        rescue StandardError => e
          errors[i] = e
        end
      end
    end
    2.times { ready.pop }
    2.times { go << true }
    threads.each { |thread| assert thread.join(30), "thread did not finish" }

    successes = results.compact
    failures = errors.compact
    assert_equal 1, successes.size, failures.map(&:message).inspect
    assert_equal 1, failures.size, successes.inspect
    assert InventoryUnit.uncached { InventoryUnit.find(unit_id).on_hand? }
    restores = InventoryLedgerEntry.uncached {
      InventoryLedgerEntry.where(
        inventory_unit_id: unit_id,
        source_type: "PosTransactionLine",
        entry_type: "return"
      ).count
    }
    assert_equal 1, restores
    loser_id = jobs.map { |job| job[:transaction].id } - [ successes.first.transaction.id ]
    loser = PosTransaction.uncached { PosTransaction.find(loser_id.first) }
    assert loser.working?
    assert_nil loser.receipt_sequence
  end

  test "complete mixed transaction versus close session never omits a completed fact" do
    Pos::TenderTypes.seed!
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 5)
    register = Register.create!(store: @store, register_number: 51, name: "Mixed close race")
    context = pos_open_context(store: @store, actor: @actor, register: register)
    transaction = Pos::StartTransaction.call(session: context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku
    )
    Pos::ExecuteUnlinkedReturn.call(
      transaction: transaction.reload,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku,
      quantity: 1,
      reason_code: "changed_mind",
      requested_return_unit_price_cents: 500
    )
    transaction.reload
    if transaction.signed_net_cents.positive?
      Pos::TenderCash.call(
        transaction: transaction,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        amount_presented_cents: transaction.total_cents
      )
    elsif transaction.signed_net_cents.negative?
      Pos::AddRefundTender.call(
        transaction: transaction,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        tender_type: TenderType.find_by!(code: "cash"),
        amount_cents: -transaction.signed_net_cents
      )
    end
    transaction.reload
    session_id = context[:session].id
    session_lock = context[:session].lock_version
    transaction_id = transaction.id
    txn_lock = transaction.lock_version
    total = transaction.total_cents
    signed_net = transaction.signed_net_cents
    actor_id = @actor.id
    ready = Queue.new
    go = Queue.new
    complete_result = nil
    close_result = nil
    complete_error = nil
    close_error = nil

    threads = [
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          go.pop
          complete_result = Pos::CompleteTransaction.call(
            transaction: PosTransaction.find(transaction_id),
            actor: User.find(actor_id),
            operation_id: SecureRandom.uuid_v7,
            expected_lock_version: txn_lock,
            expected_total_cents: total,
            expected_signed_net_cents: signed_net
          )
        rescue StandardError => e
          complete_error = e
        end
      end,
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          go.pop
          close_result = pos_close_session!(
            session: PosSession.find(session_id),
            actor: User.find(actor_id),
            expected_lock_version: session_lock,
            closing_count_cents: 0
          )
        rescue StandardError => e
          close_error = e
        end
      end
    ]
    2.times { ready.pop }
    2.times { go << true }
    threads.each { |thread| assert thread.join(30), "thread did not finish" }

    failures = [ complete_error, close_error ].compact
    assert complete_result, failures.map(&:message).inspect
    refute complete_error && close_error, failures.map(&:message).inspect

    session = PosSession.uncached { PosSession.find(session_id) }
    txn = PosTransaction.uncached { PosTransaction.find(transaction_id) }
    assert txn.completed?, complete_error&.message
    refute session.closed? && txn.working?

    if session.closed?
      assert close_result
      assert_equal session.id, txn.pos_session_id
      expected = session.opening_float_cents +
                 PosTender.joins(:pos_transaction).where(
                   pos_transactions: { pos_session_id: session.id, status: "completed" },
                   behavioral_category: "cash",
                   direction: "payment"
                 ).sum(:amount_cents) -
                 PosTender.joins(:pos_transaction).where(
                   pos_transactions: { pos_session_id: session.id, status: "completed" },
                   behavioral_category: "cash",
                   direction: "refund"
                 ).sum(:amount_cents)
      assert_equal expected, session.closing_expected_cash_cents
    else
      assert close_error
    end
  end

  test "two registers racing post-void of the same source yield one reversal" do
    Pos::TenderTypes.seed!
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 5)
    ready = prepare_sale(register_number: 61, presented_cents: 2500)
    source = Pos::CompleteTransaction.call(
      transaction: ready[:transaction],
      actor: @actor,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: ready[:transaction].lock_version,
      expected_total_cents: ready[:transaction].total_cents
    ).transaction

    first = pos_open_context(
      store: @store,
      actor: @actor,
      register: Register.create!(store: @store, register_number: 62, name: "PV A"),
      opening_float_cents: 0
    )
    second = pos_open_context(
      store: @store,
      actor: @actor,
      register: Register.create!(store: @store, register_number: 63, name: "PV B"),
      opening_float_cents: 0
    )

    source_id = source.id
    actor_id = @actor.id
    session_ids = [ first[:session].id, second[:session].id ]
    results = Array.new(2)
    errors = Array.new(2)
    ready_q = Queue.new
    go = Queue.new
    threads = session_ids.each_with_index.map do |session_id, i|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready_q << true
          go.pop
          results[i] = Pos::PostVoidTransaction.call(
            source: PosTransaction.find(source_id),
            actor: User.find(actor_id),
            session: PosSession.find(session_id),
            operation_id: SecureRandom.uuid_v7,
            reversal_transaction_id: SecureRandom.uuid_v7,
            reason_code: "entered_in_error"
          )
        rescue StandardError => e
          errors[i] = e
        end
      end
    end
    2.times { ready_q.pop }
    2.times { go << true }
    threads.each { |thread| assert thread.join(30), "thread did not finish" }

    successes = results.compact
    failures = errors.compact
    assert_equal 1, successes.size, failures.map(&:message).inspect
    assert_equal 1, failures.size, successes.inspect
    assert_match(/already been post-voided/, failures.first.message)
    assert_equal 1, PosTransaction.uncached {
      PosTransaction.completed.where(post_void_of_transaction_id: source_id).count
    }
    assert_equal 1, InventoryLedgerEntry.uncached {
      InventoryLedgerEntry.where(entry_type: "reversal", source_type: "PosTransactionLine").count
    }
  end

  test "linked return completion versus post-void never both succeed" do
    Pos::TenderTypes.seed!
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 5)
    ready = prepare_sale(register_number: 64, presented_cents: 2500)
    source = Pos::CompleteTransaction.call(
      transaction: ready[:transaction],
      actor: @actor,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: ready[:transaction].lock_version,
      expected_total_cents: ready[:transaction].total_cents
    ).transaction
    linked = prepare_linked_return(register_number: 65, original_line: source.pos_transaction_lines.first)
    pv_context = pos_open_context(
      store: @store,
      actor: @actor,
      register: Register.create!(store: @store, register_number: 66, name: "PV race"),
      opening_float_cents: 0
    )

    source_id = source.id
    linked_id = linked[:transaction].id
    linked_lock = linked[:transaction].lock_version
    linked_total = linked[:transaction].total_cents
    linked_net = linked[:transaction].signed_net_cents
    session_id = pv_context[:session].id
    actor_id = @actor.id

    complete_result = nil
    post_void_result = nil
    complete_error = nil
    post_void_error = nil
    ready_q = Queue.new
    go = Queue.new
    threads = [
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready_q << true
          go.pop
          complete_result = Pos::CompleteTransaction.call(
            transaction: PosTransaction.find(linked_id),
            actor: User.find(actor_id),
            operation_id: SecureRandom.uuid_v7,
            expected_lock_version: linked_lock,
            expected_total_cents: linked_total,
            expected_signed_net_cents: linked_net
          )
        rescue StandardError => e
          complete_error = e
        end
      end,
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready_q << true
          go.pop
          post_void_result = Pos::PostVoidTransaction.call(
            source: PosTransaction.find(source_id),
            actor: User.find(actor_id),
            session: PosSession.find(session_id),
            operation_id: SecureRandom.uuid_v7,
            reversal_transaction_id: SecureRandom.uuid_v7,
            reason_code: "entered_in_error"
          )
        rescue StandardError => e
          post_void_error = e
        end
      end
    ]
    2.times { ready_q.pop }
    2.times { go << true }
    threads.each { |thread| assert thread.join(30), "thread did not finish" }

    successes = [ complete_result, post_void_result ].compact
    failures = [ complete_error, post_void_error ].compact
    assert_equal 1, successes.size, failures.map(&:message).inspect
    assert_equal 1, failures.size, successes.inspect

    linked_txn = PosTransaction.uncached { PosTransaction.find(linked_id) }
    post_voids = PosTransaction.uncached { PosTransaction.completed.where(post_void_of_transaction_id: source_id) }
    if complete_result
      assert linked_txn.completed?
      assert_equal 0, post_voids.count
      assert_match(/linked return exists|already been post-voided/, post_void_error.message)
    else
      assert_equal 1, post_voids.count
      refute linked_txn.completed?
      assert_match(/post-voided|linked return exists/, complete_error.message)
    end
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

  def prepare_empty_sale(register_number:)
    register = Register.create!(store: @store, register_number: register_number, name: "Lane #{register_number}")
    context = pos_open_context(store: @store, actor: @actor, register: register, opening_float_cents: 10_000)
    transaction = Pos::StartTransaction.call(session: context[:session], actor: @actor)
    { context: context, transaction: transaction }
  end

  def prepare_linked_return(register_number:, original_line:)
    job = prepare_empty_sale(register_number: register_number)
    transaction = job[:transaction]
    actor = @actor
    Pos::AddLinkedReturnLine.call(
      transaction: transaction,
      actor: actor,
      expected_lock_version: transaction.lock_version,
      original_line: original_line,
      quantity: 1,
      reason_code: "changed_mind"
    )
    transaction.reload
    Pos::AddRefundTender.call(
      transaction: transaction,
      actor: actor,
      expected_lock_version: transaction.lock_version,
      tender_type: TenderType.find_by!(code: "cash"),
      amount_cents: -transaction.signed_net_cents
    )
    { context: job[:context], transaction: transaction.reload }
  end

  def prepare_unlinked_return(register_number:, unit:)
    job = prepare_empty_sale(register_number: register_number)
    transaction = job[:transaction]
    Pos::ExecuteUnlinkedReturn.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: unit.unit_identifier,
      quantity: 1,
      reason_code: "changed_mind",
      requested_return_unit_price_cents: 1200
    )
    transaction.reload
    Pos::AddRefundTender.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      tender_type: TenderType.find_by!(code: "cash"),
      amount_cents: -transaction.signed_net_cents
    )
    { context: job[:context], transaction: transaction.reload }
  end

  def prepare_unit_sale(register_number:, unit:, presented_cents:)
    register = Register.create!(store: @store, register_number: register_number, name: "Lane #{register_number}")
    context = pos_open_context(store: @store, actor: @actor, register: register)
    transaction = Pos::StartTransaction.call(session: context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: unit.unit_identifier
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
