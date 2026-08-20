# frozen_string_literal: true

module Pos
  class CompleteTransaction
    Result = Struct.new(:transaction, :operation, :replayed, keyword_init: true)

    def self.call(**attrs)
      new(**attrs).call
    end

    def self.command_payload(transaction:, operation_id:, expected_lock_version:, expected_total_cents:, expected_signed_net_cents: nil)
      {
        "transaction_id" => transaction.id.to_s,
        "operation_id" => operation_id.to_s,
        "expected_lock_version" => expected_lock_version.to_i,
        "expected_total_cents" => expected_total_cents.to_i,
        "expected_signed_net_cents" => resolve_expected_signed_net_cents!(
          transaction: transaction,
          expected_total_cents: expected_total_cents,
          expected_signed_net_cents: expected_signed_net_cents
        )
      }
    end

    def self.resolve_expected_signed_net_cents!(transaction:, expected_total_cents:, expected_signed_net_cents:)
      expected_total_cents = expected_total_cents.to_i
      if expected_signed_net_cents.nil?
        unless transaction.signed_net_cents == transaction.total_cents
          raise Pos::Error, "expected signed net is required"
        end

        expected_total_cents
      else
        expected_signed_net_cents.to_i
      end
    end

    def self.payload_hash_matches?(stored_hash, command_payload)
      current = Idempotency::CanonicalJson.hash(command_payload)
      return true if stored_hash == current
      return false unless command_payload["expected_signed_net_cents"] == command_payload["expected_total_cents"]

      legacy = command_payload.except("expected_signed_net_cents")
      stored_hash == Idempotency::CanonicalJson.hash(legacy)
    end

    def initialize(transaction:, actor:, operation_id:, expected_lock_version:, expected_total_cents:, expected_signed_net_cents: nil)
      @transaction = transaction
      @actor = actor
      @operation_id = operation_id
      @expected_lock_version = expected_lock_version.to_i
      @expected_total_cents = expected_total_cents.to_i
      @expected_signed_net_cents = expected_signed_net_cents
    end

    def call
      lease = nil
      Pos::Support.authorize!(@actor, @transaction.store)
      Pos::Support.require_transaction_cashier!(@actor, @transaction)
      @expected_signed_net_cents = self.class.resolve_expected_signed_net_cents!(
        transaction: @transaction,
        expected_total_cents: @expected_total_cents,
        expected_signed_net_cents: @expected_signed_net_cents
      )

      lease = Pos::OperationLease.begin!(
        register_id: @transaction.register_id,
        operation_id: @operation_id,
        command_payload: command_payload(@transaction),
        store_id: @transaction.store_id,
        pos_transaction_id: @transaction.id
      )
      return replay_result(lease.operation) if lease.replayed

      Pos::Support.require_active_context!(@transaction.store, @transaction.register)
      complete_commercially!(@transaction, lease.operation)
    rescue Pos::Denied => e
      record_rejection_audit!(e.message, outcome: "denied")
      fail_in_flight_lease!(lease)
      raise
    rescue Pos::PayloadMismatch, OperationLease::Error => e
      record_integrity_rejection!(e)
      raise
    rescue StandardError => e
      fail_in_flight_lease!(lease)
      record_rejection_audit!(e.message, outcome: "failed")
      raise wrap_error(e)
    end

    private

    def command_payload(transaction)
      self.class.command_payload(
        transaction: transaction,
        operation_id: @operation_id,
        expected_lock_version: @expected_lock_version,
        expected_total_cents: @expected_total_cents,
        expected_signed_net_cents: @expected_signed_net_cents
      )
    end

    def complete_commercially!(transaction, operation)
      result = nil
      PosTransaction.transaction do
        operation = PosOperation.lock.find(operation.id)
        if operation.status == "completed"
          result = replay_result(operation)
          next result
        end
        raise OperationLease::Error, "completion lease is not in flight" unless operation.status == "in_flight"

        transaction = PosTransaction.lock.find(transaction.id)
        if transaction.completed?
          raise Pos::Error, "transaction is already completed"
        end

        Pos::Support.authorize!(@actor, transaction.store)
        Pos::Support.require_active_context!(transaction.store, transaction.register)
        Pos::Support.require_transaction_cashier!(@actor, transaction)
        raise Pos::Error, "transaction is not working" unless transaction.working?
        if transaction.lock_version != @expected_lock_version
          raise Pos::StaleObject, "stale lock_version"
        end

        validate_context!(transaction)
        lock_original_sale_lines!(transaction)
        freeze_lines!(transaction)
        Pos::Support.refresh_totals!(transaction)
        Pos::CompletedTransactionIntegrity.verify!(transaction)
        if transaction.total_cents != @expected_total_cents
          raise Pos::Error, "expected total does not match amount due"
        end
        if transaction.signed_net_cents != @expected_signed_net_cents
          raise Pos::Error, "expected signed net does not match"
        end
        settle_tenders!(transaction)

        completion_time = Time.current
        business_date = transaction.reporting_period.business_date
        receipt = allocate_receipt!(transaction)
        facts = build_facts!(
          transaction: transaction,
          operation_id: operation.id,
          completion_time: completion_time,
          business_date: business_date,
          receipt: receipt
        )

        persist_completed_transaction!(transaction, facts, completion_time, business_date)
        post_inventory!(transaction, completion_time, business_date, operation.id)
        persist_completed_operation!(operation, transaction, facts, completion_time)
        record_success_audit!(transaction, operation, facts)
        record_completion_outbox!(transaction, operation, facts, completion_time)

        result = Result.new(transaction: transaction.reload, operation: operation.reload, replayed: false)
      end
      result
    end

    def validate_context!(transaction)
      session = transaction.pos_session
      period = transaction.reporting_period
      raise Pos::Error, "session is not open" unless session.open?
      raise Pos::Error, "reporting period is not open" unless period.open?
      raise Pos::Error, "register does not match session" unless transaction.register_id == session.register_id
      raise Pos::Error, "register does not match reporting period" unless transaction.register_id == period.register_id
      raise Pos::Error, "reporting period does not match session" unless transaction.reporting_period_id == session.reporting_period_id
      raise Pos::Error, "store does not match register" unless transaction.store_id == transaction.register.store_id
      raise Pos::Error, "transaction has no merchandise" if transaction.pos_transaction_lines.none?
    end

    def lock_original_sale_lines!(transaction)
      original_ids = transaction.pos_transaction_lines.filter_map(&:original_transaction_line_id).uniq.sort
      return if original_ids.empty?

      originals = PosTransactionLine.lock.where(id: original_ids).order(:id).to_a
      raise Pos::Error, "original sale line is missing" if originals.size != original_ids.size

      originals.each do |original|
        remaining = Pos::Returnability.remaining_quantity(original)
        requested = transaction.pos_transaction_lines
                               .select { |line| line.original_transaction_line_id == original.id }
                               .sum(&:quantity)
        raise Pos::Error, "original sale has been post-voided" if PosTransaction.completed.exists?(post_void_of_transaction_id: original.pos_transaction_id)
        raise Pos::Error, "return quantity exceeds remaining quantity" if requested > remaining
      end
    end

    def freeze_lines!(transaction)
      transaction.pos_transaction_lines.lock.order(:id).each do |line|
        if line.post_void_generated?
          raise Pos::Error, "ordinary completion cannot include post-void lines"
        elsif line.sale?
          Pos::FreezeSaleLine.call(transaction: transaction, line: line)
        elsif line.linked_return?
          Pos::FreezeLinkedReturnLine.call(transaction: transaction, line: line)
        elsif line.unlinked_return?
          Pos::FreezeUnlinkedReturnLine.call(transaction: transaction, line: line)
        else
          raise Pos::Error, "return line is missing linkage or unlinked-return facts"
        end
      end
    end

    def settle_tenders!(transaction)
      tenders = transaction.pos_tenders.ordered.to_a
      signed_net = transaction.signed_net_cents
      if signed_net.zero?
        raise Pos::Error, "zero-net sales cannot have tenders" if tenders.any?
        return
      end

      raise Pos::Error, "tender is required" if tenders.empty?

      if signed_net.positive?
        raise Pos::Error, "refund tenders are not supported" if tenders.any? { |tender| tender.direction != "payment" }
        settle_payments!(transaction, tenders, signed_net)
      else
        raise Pos::Error, "payment tenders are not supported" if tenders.any? { |tender| tender.direction != "refund" }
        settle_refunds!(tenders, -signed_net)
      end
    end

    def settle_payments!(transaction, tenders, due_cents)
      cash = tenders.find(&:cash?)
      non_cash = tenders.reject(&:cash?)
      non_cash_applied = non_cash.sum(&:amount_cents)

      if cash
        remaining = due_cents - non_cash_applied
        raise Pos::Error, "tenders exceed amount due" if remaining.negative?
        if cash.amount_presented_cents < remaining
          raise Pos::Error, "presented amount is less than amount due"
        end

        cash.update!(
          amount_cents: remaining,
          change_cents: cash.amount_presented_cents - remaining
        )
      elsif non_cash_applied != due_cents
        raise Pos::Error, "tenders must equal amount due"
      end

      applied = transaction.pos_tenders.payments.sum(:amount_cents)
      raise Pos::Error, "tenders must equal amount due" unless applied == due_cents
    end

    def settle_refunds!(tenders, refund_due_cents)
      cash = tenders.find(&:cash?)
      if cash && (cash.amount_presented_cents.present? || cash.change_cents.present?)
        raise Pos::Error, "Cash refund cannot have presented or change"
      end

      applied = tenders.sum(&:amount_cents)
      raise Pos::Error, "refunds must equal amount due" unless applied == refund_due_cents
    end

    def allocate_receipt!(transaction)
      register = Register.lock.find(transaction.register_id)
      sequence = register.receipt_sequence + 1
      register.update!(receipt_sequence: sequence)
      store_number = transaction.store.store_number
      register_number = register.register_number
      {
        sequence: sequence,
        store_number: store_number,
        register_number: register_number,
        reference: ReceiptIdentity.reference(
          store_number: store_number,
          register_number: register_number,
          receipt_sequence: sequence
        )
      }
    end

    def build_facts!(transaction:, operation_id:, completion_time:, business_date:, receipt:)
      Pos::CompletedEnvelopeBuilder.call(
        transaction: transaction,
        actor: @actor,
        operation_id: operation_id,
        completion_time: completion_time,
        business_date: business_date,
        receipt: receipt
      )
    end

    def persist_completed_transaction!(transaction, facts, completion_time, business_date)
      raise Pos::Error, "business date must match the reporting period" unless business_date == transaction.reporting_period.business_date

      transaction.update!(
        status: "completed",
        occurred_at: completion_time,
        completed_at: completion_time,
        business_date: business_date,
        receipt_sequence: facts.receipt_sequence,
        store_number_snapshot: facts.store_number,
        register_number_snapshot: facts.register_number,
        transaction_reference: facts.transaction_reference,
        cashier_name_snapshot: @actor.display_name
      )
    end

    def post_inventory!(transaction, completion_time, business_date, correlation_id)
      transaction.pos_transaction_lines.order(:id).each do |line|
        next if line.product_variant.derived_inventory_tracking == "non_inventory"

        if line.sale?
          Inventory::PostSale.call(
            line: line,
            occurred_at: completion_time,
            business_date: business_date,
            actor: @actor,
            correlation_id: correlation_id
          )
        elsif line.return?
          Inventory::PostReturn.call(
            line: line,
            occurred_at: completion_time,
            business_date: business_date,
            actor: @actor,
            correlation_id: correlation_id
          )
        else
          raise Pos::Error, "unknown line direction"
        end
      end
    end

    def persist_completed_operation!(operation, transaction, facts, completion_time)
      posted_at = Time.current
      operation.update!(
        status: "completed",
        fact_type: PosOperation::FACT_TYPE,
        schema_version: 2,
        pos_transaction_id: transaction.id,
        store_id: transaction.store_id,
        register_id: transaction.register_id,
        envelope: facts.envelope,
        envelope_hash: facts.envelope_hash,
        originated_at: completion_time,
        received_at: posted_at,
        posted_at: posted_at,
        lease_expires_at: nil,
        producer_client: "rails",
        producer_version: Rails.application.config.x.application_version
      )
    end

    def record_success_audit!(transaction, operation, facts)
      Audit::Recorder.record!(
        action: "pos.transaction_completed",
        outcome: "succeeded",
        actor_user: @actor,
        actor_label: @actor.display_name,
        store: transaction.store,
        register: transaction.register,
        subject: transaction,
        correlation_id: operation.id,
        after_values: success_audit_after_values(transaction, facts),
        metadata: {
          operation_id: operation.id,
          envelope_hash: facts.envelope_hash
        }
      )
    end

    def success_audit_after_values(transaction, facts)
      values = {
        receipt_sequence: facts.receipt_sequence,
        transaction_reference: facts.transaction_reference,
        total_cents: transaction.total_cents
      }
      unit_ids = transaction.pos_transaction_lines.filter_map(&:inventory_unit_id)
      values[:inventory_unit_id] = unit_ids.first.to_s if unit_ids.one?
      values[:inventory_unit_ids] = unit_ids.map(&:to_s) if unit_ids.many?
      values
    end

    def record_completion_outbox!(transaction, operation, facts, completion_time)
      Outbox::Recorder.record!(
        event_type: "pos.transaction_completed",
        aggregate: transaction,
        correlation_id: operation.id,
        occurred_at: completion_time,
        payload: {
          operation_id: operation.id,
          transaction_id: transaction.id,
          store_id: transaction.store_id,
          register_id: transaction.register_id,
          receipt_sequence: facts.receipt_sequence,
          transaction_reference: facts.transaction_reference
        }
      )
    end

    def record_rejection_audit!(message, outcome:)
      transaction = @transaction
      return if transaction.nil?

      Audit::Recorder.record!(
        action: "pos.transaction_completion_rejected",
        outcome: outcome,
        actor_user: @actor,
        actor_label: @actor.display_name,
        store: transaction.store,
        register: transaction.register,
        subject: transaction,
        reason_text: message,
        metadata: { operation_id: @operation_id }
      )
    end

    def record_integrity_rejection!(error)
      return if error.is_a?(OperationLease::Error) && error.message.match?(/still in flight/i)

      record_rejection_audit!(error.message, outcome: "failed")
    end

    def fail_in_flight_lease!(lease)
      return if lease.nil? || lease.replayed

      PosOperation.transaction do
        operation = PosOperation.lock.find_by(id: lease.operation.id)
        next unless operation&.status == "in_flight"

        OperationLease.fail!(operation)
      end
    end

    def replay_result(operation)
      Result.new(transaction: operation.pos_transaction, operation: operation.reload, replayed: true)
    end

    def wrap_error(error)
      case error
      when Pos::Error, Pos::StaleObject, Pos::Denied
        error
      else
        Pos::Error.new(error.message)
      end
    end
  end
end
