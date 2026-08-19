# frozen_string_literal: true

module Pos
  class ExecuteControlledAction
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      transaction:,
      line:,
      actor:,
      expected_lock_version:,
      action_type:,
      operation:,
      reason_code: nil,
      reason_note: nil,
      selling_unit_price_cents: nil,
      discount_basis_points: nil,
      tax_class_id: nil,
      approver_username: nil,
      approver_password: nil
    )
      @transaction = transaction
      @line = line
      @actor = actor
      @expected_lock_version = expected_lock_version
      @action_type = action_type.to_s
      @operation = operation.to_s
      @reason_code = reason_code.to_s.presence
      @reason_note = reason_note.to_s.strip.presence
      @selling_unit_price_cents = selling_unit_price_cents
      @discount_basis_points = discount_basis_points
      @tax_class_id = tax_class_id
      @approver_username = approver_username
      @approver_password = approver_password
    end

    def call
      Pos::Support.authorize!(@actor, @transaction.store)
      Pos::Support.require_active_context!(@transaction.store, @transaction.register)
      Pos::Support.require_transaction_cashier!(@actor, @transaction)
      raise Pos::Error, "line does not belong to transaction" unless @line.pos_transaction_id == @transaction.id
      raise Pos::Error, "unknown controlled action" unless PosControlledAction::ACTION_TYPES.include?(@action_type)
      raise Pos::Error, "unknown operation" unless %w[apply remove].include?(@operation)

      PosTransaction.transaction do
        transaction = Pos::Support.lock_working_transaction!(@transaction, @expected_lock_version)
        line = transaction.pos_transaction_lines.find(@line.id)
        raise Pos::Error, "controlled actions are sale-direction only" if line.return?
        existing = line.pos_controlled_actions.find_by(action_type: @action_type)

        if @operation == "remove"
          remove!(transaction, line, existing)
        else
          apply!(transaction, line, existing)
        end
        Pos::Support.refresh_totals!(transaction)
        Pos::Support.touch_working_transaction!(transaction)
        line.reload
      end
    rescue Pos::Denied => e
      record_denied!(e.message)
      raise Pos::Error, e.message if e.message.start_with?("approver")

      raise
    rescue Pos::Tax::UnresolvedApplicability => e
      raise Pos::Error, e.message
    end

    private

    def apply!(transaction, line, existing)
      policy = Pos::ControlledActionPolicy.result(user: @actor, store: transaction.store, action_type: @action_type)
      raise Pos::Denied, "not authorized to perform this action" if policy == :prohibited
      raise Pos::Error, "remove the line discount before changing the price override" if @action_type == "price_override" && line.manually_discounted?

      reason_name = Pos::ControlledActionReasons.name_for!(@action_type, @reason_code)
      if Pos::ControlledActionReasons.require_note?(@reason_code)
        raise Pos::Error, "reason note is required" if @reason_note.blank?
        raise Pos::Error, "reason note is too long" if @reason_note.length > 200
      else
        @reason_note = nil
      end

      before = snapshot_line(line)
      material = apply_mutation!(transaction, line)
      fingerprint = fingerprint_for(transaction, line, material)
      approver = Pos::AuthenticateApprover.call(
        username: @approver_username,
        password: @approver_password,
        store: transaction.store,
        action_type: @action_type,
        performer: @actor
      ) if policy == :approval_required

      Pos::Support.clear_working_tenders!(transaction)
      persist_effective_row!(transaction, line, existing, policy, reason_name, material, fingerprint, approver)
      audit_execution!(transaction, line, existing ? "changed" : "applied", before, material, policy, fingerprint, approver)
    end

    def remove!(transaction, line, existing)
      raise Pos::Error, "there is no #{@action_type.tr('_', ' ')} to remove" if existing.nil?
      policy = Pos::ControlledActionPolicy.result(user: @actor, store: transaction.store, action_type: @action_type)
      raise Pos::Denied, "not authorized to perform this action" if policy == :prohibited
      raise Pos::Error, "remove the line discount before changing the price override" if @action_type == "price_override" && line.manually_discounted?

      before = snapshot_line(line)
      restore_mutation!(line)
      Pos::Support.apply_provisional_tax!(line)
      line.save!
      existing.destroy!
      Pos::Support.clear_working_tenders!(transaction)
      Audit::Recorder.record!(
        action: "pos.#{@action_type}.removed",
        outcome: "succeeded",
        actor_user: @actor,
        store: transaction.store,
        register: transaction.register,
        subject: line,
        metadata: { transaction_id: transaction.id, line_id: line.id, before: before }
      )
    end

    def apply_mutation!(transaction, line)
      case @action_type
      when "price_override"
        cents = Pos::Support.parse_nonnegative_cents!(@selling_unit_price_cents, "price")
        raise Pos::Error, "price override must differ from the reference price" if cents == line.reference_unit_price_cents

        line.selling_unit_price_cents = cents
        line.recalc_extended!
        Pos::Support.apply_provisional_tax!(line)
        line.save!
        {
          "reference_unit_price_cents" => line.reference_unit_price_cents,
          "requested_selling_unit_price_cents" => cents,
          "quantity" => line.quantity
        }
      when "line_discount"
        bp = parse_discount_basis_points!
        raise Pos::Error, "discount must be between 1 and 10000 basis points" unless bp.between?(1, 10_000)

        basis = line.selling_unit_price_cents * line.quantity
        raise Pos::Error, "a discount cannot be applied to a zero-value line" if basis.zero?

        amount = Pos::LineDiscount.amount_cents(
          selling_unit_price_cents: line.selling_unit_price_cents,
          quantity: line.quantity,
          basis_points: bp
        )
        raise Pos::Error, "discount must change the amount charged" if amount.zero?

        line.manual_discount_basis_points = bp
        line.recalc_extended!
        Pos::Support.apply_provisional_tax!(line)
        line.save!
        {
          "selling_unit_price_cents" => line.selling_unit_price_cents,
          "quantity" => line.quantity,
          "line_selling_basis_cents" => basis,
          "discount_basis_points" => bp
        }
      when "tax_class_override"
        tax_class = TaxClass.find_by(id: @tax_class_id)
        raise Pos::Error, "Tax Class is not valid" unless tax_class&.active?
        raise Pos::Error, "Tax Class override must differ from the applied class" if tax_class.id == line.tax_class_id

        Pos::Tax::Calculate.call(store: transaction.store, tax_class: tax_class, taxable_basis_cents: line.net_merchandise_amount_cents)
        line.tax_class = tax_class
        line.tax_class_code_snapshot = tax_class.code
        line.tax_class_name_snapshot = tax_class.name
        Pos::Support.apply_provisional_tax!(line)
        line.save!
        {
          "default_tax_class_id" => line.default_tax_class_id.to_s,
          "requested_tax_class_id" => tax_class.id.to_s
        }
      end
    end

    def restore_mutation!(line)
      case @action_type
      when "price_override"
        line.selling_unit_price_cents = line.reference_unit_price_cents
        line.recalc_extended!
      when "line_discount"
        line.manual_discount_basis_points = nil
        line.recalc_extended!
      when "tax_class_override"
        default = line.default_tax_class || TaxClass.find(line.default_tax_class_id)
        line.tax_class = default
        line.tax_class_code_snapshot = default.code
        line.tax_class_name_snapshot = default.name
      end
    end

    def persist_effective_row!(transaction, line, existing, policy, reason_name, material, fingerprint, approver)
      attrs = {
        pos_transaction: transaction,
        pos_transaction_line: line,
        action_type: @action_type,
        performed_by_user: @actor,
        performed_by_name_snapshot: @actor.display_name,
        approved_by_user: approver,
        approved_by_name_snapshot: approver&.display_name,
        reason_code: @reason_code,
        reason_name_snapshot: reason_name,
        reason_note: @reason_note,
        policy_result: policy.to_s,
        policy_version: PosControlledAction::POLICY_VERSION,
        fingerprint_schema_version: PosControlledAction::FINGERPRINT_SCHEMA_VERSION,
        action_fingerprint: fingerprint,
        material_values: material,
        executed_at: Time.current
      }
      if existing
        existing.update!(attrs)
      else
        PosControlledAction.create!(attrs)
      end
    end

    def parse_discount_basis_points!
      Integer(@discount_basis_points)
    rescue ArgumentError, TypeError
      raise Pos::Error, "discount must be between 1 and 10000 basis points"
    end

    def fingerprint_for(transaction, line, material)
      Pos::ControlledActionFingerprint.call(
        action_type: @action_type,
        transaction_id: transaction.id,
        line_id: line.id,
        material_values: material,
        reason_code: @reason_code,
        reason_note: @reason_note
      )
    end

    def snapshot_line(line)
      {
        "selling_unit_price_cents" => line.selling_unit_price_cents,
        "manual_discount_basis_points" => line.manual_discount_basis_points,
        "manual_discount_cents" => line.manual_discount_cents,
        "tax_class_id" => line.tax_class_id.to_s
      }
    end

    def audit_execution!(transaction, line, verb, before, material, policy, fingerprint, approver)
      Audit::Recorder.record!(
        action: "pos.#{@action_type}.#{verb}",
        outcome: "succeeded",
        actor_user: @actor,
        store: transaction.store,
        register: transaction.register,
        subject: line,
        reason_code: @reason_code,
        reason_text: @reason_note,
        before_values: before,
        after_values: snapshot_line(line),
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
          action_type: @action_type,
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
        subject: @line,
        reason_text: message,
        metadata: { action_type: @action_type, attempted_approver: @approver_username.presence }
      )
    rescue StandardError
      nil
    end
  end
end
