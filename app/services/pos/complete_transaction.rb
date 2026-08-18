# frozen_string_literal: true

module Pos
  class CompleteTransaction
    Result = Struct.new(:transaction, :operation, :replayed, keyword_init: true)

    def self.call(**attrs)
      new(**attrs).call
    end

    def self.command_payload(transaction:, operation_id:, expected_lock_version:, expected_total_cents:)
      {
        "transaction_id" => transaction.id.to_s,
        "operation_id" => operation_id.to_s,
        "expected_lock_version" => expected_lock_version.to_i,
        "expected_total_cents" => expected_total_cents.to_i
      }
    end

    def initialize(transaction:, actor:, operation_id:, expected_lock_version:, expected_total_cents:)
      @transaction = transaction
      @actor = actor
      @operation_id = operation_id
      @expected_lock_version = expected_lock_version.to_i
      @expected_total_cents = expected_total_cents.to_i
    end

    def call
      lease = nil
      Pos::Support.authorize!(@actor, @transaction.store)
      Pos::Support.require_transaction_cashier!(@actor, @transaction)

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
        expected_total_cents: @expected_total_cents
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
        freeze_lines!(transaction)
        Pos::Support.refresh_totals!(transaction)
        Pos::CompletedTransactionIntegrity.verify!(transaction)
        if transaction.total_cents != @expected_total_cents
          raise Pos::Error, "expected total does not match amount due"
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

    def freeze_lines!(transaction)
      transaction.pos_transaction_lines.lock.each do |line|
        variant = line.product_variant
        tracking = variant.derived_inventory_tracking
        raise Pos::Error, "merchandise is not sellable" unless variant.sellable?
        unless %w[quantity non_inventory individual].include?(tracking)
          raise Pos::Error, "merchandise tracking is not supported"
        end
        raise Pos::Error, "regular price is required" if line.selling_unit_price_cents.nil?

        unit = freeze_unit_line!(transaction, line, variant, tracking)

        line.recalc_extended!
        result = Pos::Tax::Calculate.call(
          store: transaction.store,
          tax_class: line.tax_class,
          taxable_basis_cents: line.net_merchandise_amount_cents
        )
        line.line_tax_cents = result.tax_cents
        line.line_total_cents = line.net_merchandise_amount_cents + line.line_tax_cents
        line.tax_class_code_snapshot = line.tax_class.code
        line.tax_class_name_snapshot ||= line.tax_class.name
        if line.default_tax_class_id.present?
          default_class = line.default_tax_class || TaxClass.find(line.default_tax_class_id)
          line.default_tax_class_code_snapshot ||= default_class.code
          line.default_tax_class_name_snapshot ||= default_class.name
        end
        line.merchandise_snapshot = merchandise_snapshot_for(variant, line, unit)
        line.save!
        line.pos_line_tax_components.delete_all
        result.determinations.each do |determination|
          line.pos_line_tax_components.create!(
            store_tax_id: determination.store_tax_id,
            store_tax_code_snapshot: determination.store_tax_code,
            store_tax_name_snapshot: determination.store_tax_name,
            rate_percent: determination.rate_percent,
            applies: determination.applies,
            taxable_basis_cents: determination.taxable_basis_cents,
            tax_cents: determination.tax_cents,
            calculation_order: determination.calculation_order
          )
        end
      end
    rescue Pos::Tax::UnresolvedApplicability => e
      raise Pos::Error, e.message
    end

    def freeze_unit_line!(transaction, line, variant, tracking)
      if tracking == "individual"
        raise Pos::Error, "inventory unit is required" if line.inventory_unit_id.blank?
        raise Pos::Error, "quantity must be 1 for individually tracked merchandise" unless line.quantity == 1

        unit = InventoryUnit.find(line.inventory_unit_id)
        raise Pos::Error, "unit is not on hand" unless unit.on_hand?
        raise Pos::Error, "unit is not at this store" unless unit.store_id == transaction.store_id
        raise Pos::Error, "unit does not match the merchandise" unless unit.product_variant_id == variant.id
        unit
      else
        raise Pos::Error, "inventory unit must be blank" if line.inventory_unit_id.present?

        nil
      end
    rescue ActiveRecord::RecordNotFound
      raise Pos::Error, "unit is not on hand"
    end

    def merchandise_snapshot_for(variant, line, unit)
      snapshot = {
        "sku" => variant.sku,
        "description" => variant.product.name,
        "tax_class_code" => line.tax_class.code
      }
      return snapshot if unit.nil?

      condition_code = variant.merchandise_condition&.code
      raise Pos::Error, "condition is required for individually tracked merchandise" if condition_code.blank?

      snapshot.merge(
        "unit_identifier" => unit.unit_identifier,
        "condition_code" => condition_code
      )
    end

    def settle_tenders!(transaction)
      tenders = transaction.pos_tenders.ordered.to_a
      if transaction.total_cents.zero?
        raise Pos::Error, "zero-net sales cannot have tenders" if tenders.any?
        return
      end

      raise Pos::Error, "tender is required" if tenders.empty?
      raise Pos::Error, "refund tenders are not supported" if tenders.any? { |tender| tender.direction != "payment" }

      cash = tenders.find(&:cash?)
      non_cash = tenders.reject(&:cash?)
      non_cash_applied = non_cash.sum(&:amount_cents)

      if cash
        remaining = transaction.total_cents - non_cash_applied
        raise Pos::Error, "tenders exceed amount due" if remaining.negative?
        if cash.amount_presented_cents < remaining
          raise Pos::Error, "presented amount is less than amount due"
        end

        cash.update!(
          amount_cents: remaining,
          change_cents: cash.amount_presented_cents - remaining
        )
      elsif non_cash_applied != transaction.total_cents
        raise Pos::Error, "tenders must equal amount due"
      end

      applied = transaction.pos_tenders.sum(:amount_cents)
      raise Pos::Error, "tenders must equal amount due" unless applied == transaction.total_cents
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
      envelope = {
        "schema_version" => 2,
        "operation" => {
          "operation_id" => operation_id.to_s,
          "fact_type" => PosOperation::FACT_TYPE
        },
        "origin" => {
          "store_id" => transaction.store_id.to_s,
          "register_id" => transaction.register_id.to_s,
          "pos_session_id" => transaction.pos_session_id.to_s,
          "reporting_period_id" => transaction.reporting_period_id.to_s,
          "performed_by_user_id" => transaction.cashier_user_id.to_s,
          "performed_by_name" => @actor.display_name
        },
        "receipt" => {
          "sequence" => receipt.fetch(:sequence),
          "store_number" => receipt.fetch(:store_number),
          "register_number" => receipt.fetch(:register_number),
          "reference" => receipt.fetch(:reference)
        },
        "transaction" => {
          "transaction_id" => transaction.id.to_s,
          "currency_code" => transaction.currency_code,
          "occurred_at" => completion_time.utc.iso8601(6),
          "business_date" => business_date.iso8601,
          "subtotal_cents" => transaction.subtotal_cents,
          "tax_cents" => transaction.tax_cents,
          "total_cents" => transaction.total_cents,
          "signed_net_cents" => transaction.total_cents
        },
        "lines" => transaction.pos_transaction_lines.reload.map { |line| envelope_line(line) },
        "tenders" => transaction.pos_tenders.ordered.map { |tender| envelope_tender(tender) }
      }
      envelope["transaction"]["discount_cents"] = transaction.discount_cents unless transaction.discount_cents.zero?
      actions = transaction.pos_controlled_actions.order(:executed_at, :id).map { |action| envelope_controlled_action(action) }
      envelope["controlled_actions"] = actions if actions.any?
      facts = CompletedTransactionFacts.new(envelope)
      facts.verify!
      facts
    end

    def envelope_line(line)
      payload = {
        "line_id" => line.id.to_s,
        "line_number" => line.line_number,
        "direction" => line.direction,
        "product_variant_id" => line.product_variant_id.to_s,
        "quantity" => line.quantity,
        "reference_unit_price_cents" => line.reference_unit_price_cents,
        "selling_unit_price_cents" => line.selling_unit_price_cents,
        "extended_selling_amount_cents" => line.extended_selling_amount_cents,
        "line_tax_cents" => line.line_tax_cents,
        "line_total_cents" => line.line_total_cents,
        "tax_class_id" => line.tax_class_id.to_s,
        "tax_class_code" => line.tax_class_code_snapshot,
        "merchandise_snapshot" => line.merchandise_snapshot,
        "tax_components" => line.pos_line_tax_components.order(:calculation_order, :store_tax_code_snapshot, :id).map do |component|
          {
            "store_tax_id" => component.store_tax_id.to_s,
            "store_tax_code" => component.store_tax_code_snapshot,
            "store_tax_name" => component.store_tax_name_snapshot,
            "rate_percent" => format("%.3f", component.rate_percent),
            "applies" => component.applies,
            "taxable_basis_cents" => component.taxable_basis_cents,
            "tax_cents" => component.tax_cents,
            "calculation_order" => component.calculation_order
          }
        end
      }
      payload["inventory_unit_id"] = line.inventory_unit_id.to_s if line.inventory_unit_id.present?
      if line.price_overridden?
        unit_variance = line.selling_unit_price_cents - line.reference_unit_price_cents
        payload["override"] = {
          "reference_unit_price_cents" => line.reference_unit_price_cents,
          "selling_unit_price_cents" => line.selling_unit_price_cents,
          "unit_variance_cents" => unit_variance,
          "line_variance_cents" => unit_variance * line.quantity
        }
      end
      if line.manually_discounted?
        payload["discount"] = {
          "source" => "manual",
          "method" => "percentage",
          "basis_points" => line.manual_discount_basis_points,
          "discount_cents" => line.manual_discount_cents,
          "net_merchandise_amount_cents" => line.net_merchandise_amount_cents
        }
      end
      if line.default_tax_class_id.present?
        payload["default_tax_class_id"] = line.default_tax_class_id.to_s
        payload["default_tax_class_code"] = line.default_tax_class_code_snapshot
        payload["default_tax_class_name"] = line.default_tax_class_name_snapshot
      end
      payload["tax_class_name"] = line.tax_class_name_snapshot if line.tax_class_name_snapshot.present?
      payload
    end

    def envelope_controlled_action(action)
      payload = {
        "action" => action.action_type,
        "subject" => { "line_id" => action.pos_transaction_line_id.to_s },
        "performed_by_user_id" => action.performed_by_user_id.to_s,
        "performed_by_name" => action.performed_by_name_snapshot,
        "reason" => {
          "code" => action.reason_code,
          "name" => action.reason_name_snapshot
        },
        "policy_context" => {
          "result" => action.policy_result,
          "version" => action.policy_version
        },
        "material_values" => action.material_values,
        "fingerprint" => action.action_fingerprint,
        "executed_at" => action.executed_at.utc.iso8601(6)
      }
      payload["reason"]["note"] = action.reason_note if action.reason_note.present?
      if action.approved_by_user_id.present?
        payload["approved_by_user_id"] = action.approved_by_user_id.to_s
        payload["approved_by_name"] = action.approved_by_name_snapshot
      end
      payload
    end

    def envelope_tender(tender)
      payload = {
        "tender_id" => tender.id.to_s,
        "tender_number" => tender.tender_number,
        "tender_type" => tender.tender_type,
        "tender_name" => tender.tender_name,
        "behavioral_category" => tender.behavioral_category,
        "direction" => tender.direction,
        "amount_cents" => tender.amount_cents
      }
      if tender.cash?
        payload["amount_presented_cents"] = tender.amount_presented_cents
        payload["change_cents"] = tender.change_cents
      end
      payload["external_reference"] = tender.external_reference if tender.external_reference.present?
      payload
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
      transaction.pos_transaction_lines.each do |line|
        next if line.product_variant.derived_inventory_tracking == "non_inventory"

        Inventory::PostSale.call(
          line: line,
          occurred_at: completion_time,
          business_date: business_date,
          actor: @actor,
          correlation_id: correlation_id
        )
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
