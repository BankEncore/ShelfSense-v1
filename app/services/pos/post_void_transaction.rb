# frozen_string_literal: true

module Pos
  class PostVoidTransaction
    Result = Struct.new(:transaction, :operation, :replayed, keyword_init: true)
    CONFLICT = Inventory::PostPostVoid::CONFLICT

    def self.call(**attrs)
      new(**attrs).call
    end

    def self.command_payload(
      source:,
      reversal_transaction_id:,
      reason_code:,
      reason_note:,
      card_reversals:
    )
      payload = {
        "source_transaction_id" => source.id.to_s,
        "prospective_reversal_transaction_id" => reversal_transaction_id.to_s,
        "source_completion_operation_id" => source_operation(source).id.to_s,
        "source_envelope_hash" => source_operation(source).envelope_hash,
        "reason_code" => reason_code.to_s,
        "card_reversals" => card_reversals
      }
      payload["reason_note"] = reason_note.to_s if reason_code.to_s == "other"
      payload
    end

    def self.source_operation(source)
      PosOperation.find_by!(pos_transaction_id: source.id, status: "completed", fact_type: PosOperation::FACT_TYPE)
    end

    def initialize(
      source:,
      actor:,
      session:,
      operation_id:,
      reversal_transaction_id:,
      reason_code:,
      reason_note: nil,
      card_reversals: [],
      approver_username: nil,
      approver_password: nil
    )
      @source = source
      @actor = actor
      @session = session
      @operation_id = operation_id
      @reversal_transaction_id = reversal_transaction_id
      @reason_code = reason_code.to_s
      @reason_note = reason_note.to_s.strip.presence
      @card_reversals = normalize_card_reversals(card_reversals)
      @approver_username = approver_username
      @approver_password = approver_password
    end

    def call
      lease = nil
      Pos::Support.authorize!(@actor, @source.store)
      prepare_reason!
      validate_card_reversals!(@source)
      source_operation = self.class.source_operation(@source)
      payload = self.class.command_payload(
        source: @source,
        reversal_transaction_id: @reversal_transaction_id,
        reason_code: @reason_code,
        reason_note: @reason_note,
        card_reversals: @card_reversals
      )

      lease = Pos::OperationLease.begin!(
        register_id: @session.register_id,
        operation_id: @operation_id,
        command_payload: payload,
        store_id: @source.store_id,
        command_type: PosOperation::POST_VOID_COMMAND_TYPE
      )
      return replay_result(lease.operation) if lease.replayed

      Pos::Support.require_active_context!(@source.store, @session.register)
      Pos::Support.require_session_cashier!(@actor, @session)
      complete!(source_operation, lease.operation, payload)
    rescue Pos::Denied => e
      record_denied!(e.message)
      fail_in_flight_lease!(lease)
      raise
    rescue Pos::PayloadMismatch, OperationLease::Error => e
      record_denied!(e.message, outcome: "failed")
      raise
    rescue StandardError => e
      fail_in_flight_lease!(lease)
      record_denied!(e.message, outcome: "failed")
      raise wrap_error(e)
    end

    private

    def complete!(source_operation, operation, payload)
      result = nil
      PosTransaction.transaction do
        operation = PosOperation.lock.find(operation.id)
        if operation.status == "completed"
          result = replay_result(operation)
          next result
        end
        raise OperationLease::Error, "completion lease is not in flight" unless operation.status == "in_flight"

        session = Pos::Support.lock_open_cashier_session!(@session, @actor)
        clear_or_refuse_working_basket!(session)
        raise Pos::Error, "register does not match session" unless session.register.store_id == @source.store_id
        raise Pos::Error, "post-void is not at this store" unless session.store_id == @source.store_id

        source = PosTransaction.lock.find(@source.id)
        raise Pos::Error, "transaction is not completed" unless source.completed?
        raise Pos::Error, "cannot post-void a post-void" if source.post_void?
        raise Pos::Error, "post-void is not at this store" unless source.store_id == session.store_id
        if PosTransaction.completed.exists?(post_void_of_transaction_id: source.id)
          raise Pos::Error, "transaction has already been post-voided"
        end

        source_lines = source.pos_transaction_lines.lock.order(:id).to_a
        raise Pos::Error, "transaction has no merchandise" if source_lines.empty?
        refuse_linked_returns!(source_lines)
        validate_card_reversals!(source)

        policy = Pos::ControlledActionPolicy.result(user: @actor, store: source.store, action_type: "post_void")
        raise Pos::Denied, "not authorized to perform this action" if policy == :prohibited
        approver = if policy == :approval_required
          Pos::AuthenticateApprover.call(
            username: @approver_username,
            password: @approver_password,
            store: source.store,
            action_type: "post_void",
            performer: @actor
          )
        end

        reversal = build_reversal!(session, source, source_lines)
        persist_action!(reversal, policy, approver, source_operation)
        freeze_and_total!(reversal)
        reversal.reload
        Pos::PostVoidIntegrity.verify!(source: source, reversal: reversal)
        Pos::CompletedTransactionIntegrity.verify!(reversal)
        settle_generated_tenders!(reversal)

        completion_time = Time.current
        business_date = session.reporting_period.business_date
        receipt = allocate_receipt!(reversal)
        facts = Pos::CompletedEnvelopeBuilder.call(
          transaction: reversal,
          actor: @actor,
          operation_id: operation.id,
          completion_time: completion_time,
          business_date: business_date,
          receipt: receipt
        )
        persist_completed_transaction!(reversal, facts, completion_time, business_date)
        post_inventory!(reversal, completion_time, business_date, operation.id)
        persist_completed_operation!(operation, reversal, facts, completion_time)
        record_success_audit!(reversal, operation, facts, source)
        record_completion_outbox!(reversal, operation, facts, completion_time)
        result = Result.new(transaction: reversal.reload, operation: operation.reload, replayed: false)
      end
      result
    end

    def refuse_linked_returns!(source_lines)
      sale_ids = source_lines.select(&:sale?).map(&:id)
      return if sale_ids.empty?

      working = PosTransactionLine.joins(:pos_transaction)
                                  .where(original_transaction_line_id: sale_ids, direction: "return")
                                  .where(pos_transactions: { status: "working" })
      raise Pos::Error, "a working linked return exists for this transaction" if working.exists?

      completed = Pos::Returnability.effective_completed_linked_returns(sale_ids)
      raise Pos::Error, "a completed linked return exists for this transaction" if completed.exists?
    end

    def clear_or_refuse_working_basket!(session)
      working = session.pos_transactions.working.first
      return if working.nil?
      if working.pos_transaction_lines.exists? || working.pos_tenders.exists?
        raise Pos::Error, "Complete or cancel the current transaction before post-void."
      end

      Pos::CancelTransaction.call(
        transaction: working,
        actor: @actor,
        expected_lock_version: working.lock_version
      )
    end

    def validate_card_reversals!(source)
      card_tenders = source.pos_tenders.select { |tender| tender.behavioral_category == "card" }
      submitted = @card_reversals.index_by { |row| row["source_tender_id"] }
      card_tenders.each do |tender|
        row = submitted[tender.id.to_s]
        raise Pos::Error, "Card reversal confirmation is required" if row.nil? || row["confirmed"] != true
      end
      extra = submitted.keys - card_tenders.map { |tender| tender.id.to_s }
      raise Pos::Error, "Card reversal confirmation is invalid" if extra.any?
    end

    def build_reversal!(session, source, source_lines)
      reversal = PosTransaction.create!(
        id: @reversal_transaction_id,
        store: session.store,
        register: session.register,
        pos_session: session,
        reporting_period: session.reporting_period,
        cashier_user: session.cashier_user,
        status: "working",
        currency_code: source.currency_code,
        post_void_of_transaction_id: source.id
      )
      source_lines.each_with_index do |source_line, index|
        reversal.pos_transaction_lines.create!(
          product_variant_id: source_line.product_variant_id,
          inventory_unit_id: source_line.inventory_unit_id,
          tax_class_id: source_line.tax_class_id,
          tax_class_code_snapshot: source_line.tax_class_code_snapshot,
          tax_class_name_snapshot: source_line.tax_class_name_snapshot,
          default_tax_class_id: source_line.default_tax_class_id,
          default_tax_class_code_snapshot: source_line.default_tax_class_code_snapshot,
          default_tax_class_name_snapshot: source_line.default_tax_class_name_snapshot,
          line_number: index + 1,
          direction: source_line.sale? ? "return" : "sale",
          quantity: source_line.quantity,
          reference_unit_price_cents: source_line.reference_unit_price_cents,
          selling_unit_price_cents: source_line.selling_unit_price_cents,
          extended_selling_amount_cents: source_line.extended_selling_amount_cents,
          manual_discount_basis_points: source_line.manual_discount_basis_points,
          manual_discount_cents: source_line.manual_discount_cents,
          net_merchandise_amount_cents: source_line.net_merchandise_amount_cents,
          line_tax_cents: source_line.line_tax_cents,
          line_total_cents: source_line.line_total_cents,
          merchandise_snapshot: source_line.merchandise_snapshot.deep_dup,
          post_void_source_line_id: source_line.id
        )
      end
      source.pos_tenders.ordered.each_with_index do |source_tender, index|
        reversal_direction = source_tender.direction == "payment" ? "refund" : "payment"
        attrs = {
          tender_number: index + 1,
          tender_type_id: source_tender.tender_type_id,
          tender_type: source_tender.tender_type,
          tender_name: source_tender.tender_name,
          behavioral_category: source_tender.behavioral_category,
          direction: reversal_direction,
          amount_cents: source_tender.amount_cents,
          post_void_source_tender_id: source_tender.id
        }
        if source_tender.behavioral_category == "cash" && reversal_direction == "payment"
          attrs[:amount_presented_cents] = source_tender.amount_cents
          attrs[:change_cents] = 0
        end
        if source_tender.behavioral_category == "card"
          row = @card_reversals.find { |entry| entry["source_tender_id"] == source_tender.id.to_s }
          attrs[:external_reference] = row["external_reference"] if row && row["external_reference"].present?
        end
        reversal.pos_tenders.create!(attrs)
      end
      reversal
    end

    def persist_action!(reversal, policy, approver, source_operation)
      material = {
        "source_transaction_id" => @source.id.to_s,
        "prospective_reversal_transaction_id" => reversal.id.to_s,
        "source_completion_operation_id" => source_operation.id.to_s,
        "source_envelope_hash" => source_operation.envelope_hash,
        "card_reversals" => @card_reversals
      }
      fingerprint = Pos::ControlledActionFingerprint.call(
        action_type: "post_void",
        transaction_id: reversal.id,
        line_id: nil,
        material_values: material,
        reason_code: @reason_code,
        reason_note: @reason_note
      )
      reversal.pos_controlled_actions.create!(
        action_type: "post_void",
        performed_by_user: @actor,
        performed_by_name_snapshot: @actor.display_name,
        approved_by_user: approver,
        approved_by_name_snapshot: approver&.display_name,
        reason_code: @reason_code,
        reason_name_snapshot: @reason_name,
        reason_note: @reason_note,
        policy_result: policy.to_s,
        policy_version: PosControlledAction::POLICY_VERSION,
        fingerprint_schema_version: PosControlledAction::FINGERPRINT_SCHEMA_VERSION,
        action_fingerprint: fingerprint,
        material_values: material,
        executed_at: Time.current
      )
    end

    def freeze_and_total!(reversal)
      reversal.pos_transaction_lines.lock.order(:id).each do |line|
        Pos::FreezePostVoidLine.call(transaction: reversal, line: line)
      end
      Pos::Support.refresh_totals!(reversal)
    end

    def settle_generated_tenders!(reversal)
      tenders = reversal.pos_tenders.ordered.to_a
      signed_net = reversal.signed_net_cents
      if signed_net.zero?
        raise Pos::Error, "zero-net post-void cannot have tenders" if tenders.any?
        return
      end
      raise Pos::Error, "tender is required" if tenders.empty?
      applied = tenders.sum(&:amount_cents)
      raise Pos::Error, "tenders must equal amount due" unless applied == signed_net.abs
      if signed_net.positive?
        raise Pos::Error, "refund tenders are not supported" if tenders.any? { |tender| tender.direction != "payment" }
      else
        raise Pos::Error, "payment tenders are not supported" if tenders.any? { |tender| tender.direction != "refund" }
      end
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

        Inventory::PostPostVoid.call(
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

    def record_success_audit!(transaction, operation, facts, source)
      Audit::Recorder.record!(
        action: "pos.post_void.applied",
        outcome: "succeeded",
        actor_user: @actor,
        actor_label: @actor.display_name,
        store: transaction.store,
        register: transaction.register,
        subject: transaction,
        correlation_id: operation.id,
        after_values: {
          source_transaction_id: source.id,
          receipt_sequence: facts.receipt_sequence,
          transaction_reference: facts.transaction_reference,
          reason_code: @reason_code
        },
        metadata: { operation_id: operation.id, envelope_hash: facts.envelope_hash }
      )
      Audit::Recorder.record!(
        action: "pos.transaction_completed",
        outcome: "succeeded",
        actor_user: @actor,
        actor_label: @actor.display_name,
        store: transaction.store,
        register: transaction.register,
        subject: transaction,
        correlation_id: operation.id,
        after_values: {
          receipt_sequence: facts.receipt_sequence,
          transaction_reference: facts.transaction_reference,
          total_cents: transaction.total_cents
        },
        metadata: { operation_id: operation.id, envelope_hash: facts.envelope_hash }
      )
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

    def prepare_reason!
      @reason_name = Pos::PostVoidReasons.name_for!(@reason_code)
      if Pos::PostVoidReasons.require_note?(@reason_code)
        raise Pos::Error, "reason note is required" if @reason_note.blank?
        raise Pos::Error, "reason note is too long" if @reason_note.length > 200
      else
        @reason_note = nil
      end
    end

    def normalize_card_reversals(rows)
      Array(rows).map do |row|
        attrs = row.respond_to?(:to_unsafe_h) ? row.to_unsafe_h : row
        attrs = attrs.stringify_keys
        {
          "source_tender_id" => attrs["source_tender_id"].to_s,
          "confirmed" => ActiveModel::Type::Boolean.new.cast(attrs["confirmed"]) == true,
          "external_reference" => attrs["external_reference"].to_s.strip.presence
        }.compact
      end
    end

    def record_denied!(message, outcome: "denied")
      Audit::Recorder.record!(
        action: "pos.post_void.denied",
        outcome: outcome,
        actor_user: @actor,
        actor_label: @actor.display_name,
        store: @source.store,
        register: @session&.register,
        subject: @source,
        reason_text: message,
        metadata: { operation_id: @operation_id }
      )
    rescue StandardError
      nil
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
      if error.is_a?(ActiveRecord::RecordNotUnique) && error.message.include?("index_pos_transactions_one_post_void_per_source")
        return Pos::Error.new("transaction has already been post-voided")
      end

      Pos::Error.new(error.message)
    end
  end
end
