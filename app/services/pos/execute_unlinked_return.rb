# frozen_string_literal: true

module Pos
  class ExecuteUnlinkedReturn
    STALE_PREVIEW_MESSAGE = "Merchandise changed. Resolve the return again."

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      transaction:,
      actor:,
      expected_lock_version:,
      identifier:,
      quantity:,
      reason_code:,
      requested_return_unit_price_cents:,
      reason_note: nil,
      approver_username: nil,
      approver_password: nil,
      expected_product_variant_id: nil,
      expected_inventory_unit_id: nil,
      expected_reference_unit_price_cents: nil,
      expected_tax_class_id: nil
    )
      @transaction = transaction
      @actor = actor
      @expected_lock_version = expected_lock_version
      @identifier = identifier
      @quantity = quantity.to_i
      @reason_code = reason_code.to_s
      @reason_note = reason_note.to_s.strip.presence
      @requested_return_unit_price_cents = requested_return_unit_price_cents
      @approver_username = approver_username
      @approver_password = approver_password
      @expected_product_variant_id = expected_product_variant_id.to_s.presence
      @expected_inventory_unit_id = expected_inventory_unit_id.to_s.presence
      @expected_reference_unit_price_cents = expected_reference_unit_price_cents
      @expected_tax_class_id = expected_tax_class_id.to_s.presence
    end

    def call
      Pos::Support.authorize!(@actor, @transaction.store)
      Pos::Support.require_active_context!(@transaction.store, @transaction.register)
      Pos::Support.require_transaction_cashier!(@actor, @transaction)
      raise Pos::Error, "quantity must be positive" unless @quantity.positive?

      @selling_unit_price_cents = Pos::Support.parse_nonnegative_cents!(
        @requested_return_unit_price_cents,
        "return price"
      )
      @reason_name = Pos::ReturnReasons.name_for!(@reason_code)
      if Pos::ReturnReasons.require_note?(@reason_code)
        raise Pos::Error, "reason note is required" if @reason_note.blank?
        raise Pos::Error, "reason note is too long" if @reason_note.length > 200
      else
        @reason_note = nil
      end

      PosTransaction.transaction do
        transaction = Pos::Support.lock_working_transaction!(@transaction, @expected_lock_version)
        resolved = Pos::ResolveUnlinkedReturnMerchandise.call(
          identifier: @identifier,
          store: transaction.store,
          lock_unit: true
        )
        capture_resolved!(resolved)
        validate_resolved!(resolved)
        preflight_valuation!(transaction, resolved)

        @line_id = SecureRandom.uuid_v7
        line_number = next_line_number(transaction)
        material = material_values(resolved)
        fingerprint = fingerprint_for(transaction, material)
        policy = Pos::ControlledActionPolicy.result(
          user: @actor,
          store: transaction.store,
          action_type: "unlinked_return"
        )
        raise Pos::Denied, "not authorized to perform this action" if policy == :prohibited

        approver = if policy == :approval_required
          Pos::AuthenticateApprover.call(
            username: @approver_username,
            password: @approver_password,
            store: transaction.store,
            action_type: "unlinked_return",
            performer: @actor
          )
        end

        Pos::Support.clear_working_tenders!(transaction)
        line = build_line!(transaction, resolved, line_number)
        Pos::Support.apply_provisional_tax!(line)
        line.save!
        persist_action!(transaction, line, policy, material, fingerprint, approver)
        Pos::Support.refresh_totals!(transaction)
        Pos::Support.touch_working_transaction!(transaction)
        audit_applied!(transaction, line, policy, material, fingerprint, approver)
        line
      end
    rescue Pos::Denied => e
      record_denied!(e.message)
      raise Pos::Error, e.message if e.message.start_with?("approver")

      raise
    rescue Pos::Tax::UnresolvedApplicability, Inventory::ReturnValuation::Error => e
      raise Pos::Error, e.message
    end

    private

    def capture_resolved!(resolved)
      @resolved_product_variant_id = resolved.variant.id.to_s
      @resolved_inventory_unit_id = resolved.inventory_unit&.id&.to_s
      @resolved_reference_unit_price_cents = resolved.reference_unit_price_cents
    end

    def validate_resolved!(resolved)
      if resolved.quantity_fixed && @quantity != 1
        raise Pos::Error, "quantity must be 1 for individually tracked merchandise"
      end
      return if @expected_product_variant_id.blank? &&
                @expected_inventory_unit_id.blank? &&
                @expected_reference_unit_price_cents.nil? &&
                @expected_tax_class_id.blank?

      expected_unit = @expected_inventory_unit_id
      actual_unit = resolved.inventory_unit&.id&.to_s
      expected_reference = if @expected_reference_unit_price_cents.nil?
        nil
      else
        Integer(@expected_reference_unit_price_cents)
      end
      stale = @expected_product_variant_id.present? && @expected_product_variant_id != resolved.variant.id.to_s
      stale ||= expected_unit.present? && expected_unit != actual_unit.to_s
      stale ||= !expected_reference.nil? && expected_reference != resolved.reference_unit_price_cents
      stale ||= @expected_tax_class_id.present? && @expected_tax_class_id != resolved.tax_class.id.to_s
      raise Pos::InvalidatedDialogBasis, STALE_PREVIEW_MESSAGE if stale
    rescue ArgumentError, TypeError
      raise Pos::InvalidatedDialogBasis, STALE_PREVIEW_MESSAGE
    end

    def preflight_valuation!(transaction, resolved)
      return unless %w[quantity individual].include?(resolved.tracking)

      Inventory::ReturnValuation.call(
        store: transaction.store,
        variant: resolved.variant,
        quantity: resolved.quantity_fixed ? 1 : @quantity,
        inventory_unit: resolved.inventory_unit
      )
    end

    def material_values(resolved)
      values = {
        "product_variant_id" => resolved.variant.id.to_s,
        "quantity" => resolved.quantity_fixed ? 1 : @quantity,
        "reference_unit_price_cents" => resolved.reference_unit_price_cents,
        "requested_return_unit_price_cents" => @selling_unit_price_cents,
        "tax_class_id" => resolved.tax_class.id.to_s
      }
      values["inventory_unit_id"] = resolved.inventory_unit.id.to_s if resolved.inventory_unit
      values
    end

    def fingerprint_for(transaction, material)
      Pos::ControlledActionFingerprint.call(
        action_type: "unlinked_return",
        transaction_id: transaction.id,
        line_id: @line_id,
        material_values: material,
        reason_code: @reason_code,
        reason_note: @reason_note
      )
    end

    def next_line_number(transaction)
      (transaction.pos_transaction_lines.maximum(:line_number) || 0) + 1
    end

    def build_line!(transaction, resolved, line_number)
      quantity = resolved.quantity_fixed ? 1 : @quantity
      line = transaction.pos_transaction_lines.build(
        id: @line_id,
        line_number: line_number,
        direction: "return",
        product_variant: resolved.variant,
        inventory_unit: resolved.inventory_unit,
        quantity: quantity,
        reference_unit_price_cents: resolved.reference_unit_price_cents,
        selling_unit_price_cents: @selling_unit_price_cents,
        tax_class: resolved.tax_class,
        tax_class_code_snapshot: resolved.tax_class.code,
        tax_class_name_snapshot: resolved.tax_class.name,
        default_tax_class: resolved.tax_class,
        default_tax_class_code_snapshot: resolved.tax_class.code,
        default_tax_class_name_snapshot: resolved.tax_class.name,
        pricing_method_snapshot: "configured",
        manual_discount_cents: 0,
        return_reason_code: @reason_code,
        return_reason_name_snapshot: @reason_name,
        return_reason_note: @reason_note
      )
      line.extended_selling_amount_cents = line.selling_unit_price_cents * line.quantity
      line.net_merchandise_amount_cents = line.extended_selling_amount_cents
      line
    end

    def persist_action!(transaction, line, policy, material, fingerprint, approver)
      PosControlledAction.create!(
        pos_transaction: transaction,
        pos_transaction_line: line,
        action_type: "unlinked_return",
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

    def audit_applied!(transaction, line, policy, material, fingerprint, approver)
      Audit::Recorder.record!(
        action: "pos.unlinked_return.applied",
        outcome: "succeeded",
        actor_user: @actor,
        store: transaction.store,
        register: transaction.register,
        subject: line,
        reason_code: @reason_code,
        reason_text: @reason_note,
        after_values: {
          quantity: line.quantity,
          reference_unit_price_cents: line.reference_unit_price_cents,
          selling_unit_price_cents: line.selling_unit_price_cents
        },
        metadata: {
          transaction_id: transaction.id,
          line_id: line.id,
          policy_result: policy.to_s,
          policy_version: PosControlledAction::POLICY_VERSION,
          fingerprint: fingerprint,
          material_values: material,
          approved_by_user_id: approver&.id
        }
      )
      return unless approver

      Audit::Recorder.record!(
        action: "pos.controlled_action.approved",
        outcome: "succeeded",
        actor_user: approver,
        store: transaction.store,
        register: transaction.register,
        subject: line,
        reason_code: @reason_code,
        metadata: {
          transaction_id: transaction.id,
          line_id: line.id,
          action_type: "unlinked_return",
          performed_by_user_id: @actor.id,
          fingerprint: fingerprint
        }
      )
    end

    def record_denied!(message)
      Audit::Recorder.record!(
        action: "pos.controlled_action.denied",
        outcome: "denied",
        actor_user: @actor,
        store: @transaction.store,
        register: @transaction.register,
        subject: @transaction,
        reason_text: message,
        metadata: {
          action_type: "unlinked_return",
          prospective_line_id: @line_id,
          product_variant_id: @resolved_product_variant_id || @expected_product_variant_id,
          inventory_unit_id: @resolved_inventory_unit_id || @expected_inventory_unit_id,
          quantity: @quantity,
          reference_unit_price_cents: @resolved_reference_unit_price_cents || @expected_reference_unit_price_cents,
          requested_return_unit_price_cents: @selling_unit_price_cents,
          attempted_approver: @approver_username.presence
        }.compact
      )
    rescue StandardError
      nil
    end
  end
end
