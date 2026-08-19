# frozen_string_literal: true

module Pos
  class AddLinkedReturnLine
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      transaction:,
      actor:,
      expected_lock_version:,
      original_line:,
      quantity:,
      reason_code:,
      reason_note: nil
    )
      @transaction = transaction
      @actor = actor
      @expected_lock_version = expected_lock_version
      @original_line = original_line
      @quantity = quantity.to_i
      @reason_code = reason_code.to_s
      @reason_note = reason_note.to_s.strip.presence
    end

    def call
      Pos::Support.authorize!(@actor, @transaction.store)
      Pos::Support.require_active_context!(@transaction.store, @transaction.register)
      Pos::Support.require_transaction_cashier!(@actor, @transaction)
      raise Pos::Error, "quantity must be positive" unless @quantity.positive?

      reason_name = Pos::ReturnReasons.name_for!(@reason_code)
      if Pos::ReturnReasons.require_note?(@reason_code)
        raise Pos::Error, "reason note is required" if @reason_note.blank?
        raise Pos::Error, "reason note is too long" if @reason_note.length > 200
      else
        @reason_note = nil
      end

      PosTransaction.transaction do
        transaction = Pos::Support.lock_working_transaction!(@transaction, @expected_lock_version)
        original = PosTransactionLine.find(@original_line.id)
        validate_original!(transaction, original)
        remaining = Pos::Returnability.remaining_quantity(original)
        raise Pos::Error, "return quantity exceeds remaining quantity" if @quantity > remaining
        if transaction.pos_transaction_lines.exists?(original_transaction_line_id: original.id)
          raise Pos::Error, "original line is already on this transaction"
        end

        Pos::Support.clear_working_tenders!(transaction)
        allocation = Pos::HistoricalReturnAllocation.call(original_line: original, requested_quantity: @quantity)
        line = build_line!(transaction, original, allocation, reason_name)
        replace_tax_components!(line, allocation)
        Pos::Support.refresh_totals!(transaction)
        record_added_audit!(transaction, line, original)
        line
      end
    end

    private

    def validate_original!(transaction, original)
      raise Pos::Error, "original line is not a completed sale" unless original.sale?
      raise Pos::Error, "original line is not a completed sale" unless original.pos_transaction.completed?
      raise Pos::Error, "original sale is not at this store" unless original.pos_transaction.store_id == transaction.store_id
    end

    def build_line!(transaction, original, allocation, reason_name)
      line = transaction.pos_transaction_lines.build(
        line_number: next_line_number(transaction),
        direction: "return",
        original_transaction_line: original,
        product_variant_id: original.product_variant_id,
        inventory_unit_id: original.inventory_unit_id,
        quantity: allocation.quantity,
        reference_unit_price_cents: original.reference_unit_price_cents,
        selling_unit_price_cents: original.selling_unit_price_cents,
        extended_selling_amount_cents: allocation.extended_selling_amount_cents,
        manual_discount_basis_points: original.manual_discount_basis_points,
        manual_discount_cents: allocation.manual_discount_cents,
        net_merchandise_amount_cents: allocation.net_merchandise_amount_cents,
        line_tax_cents: allocation.line_tax_cents,
        line_total_cents: allocation.line_total_cents,
        tax_class_id: original.tax_class_id,
        tax_class_code_snapshot: original.tax_class_code_snapshot,
        tax_class_name_snapshot: original.tax_class_name_snapshot,
        default_tax_class_id: original.default_tax_class_id,
        default_tax_class_code_snapshot: original.default_tax_class_code_snapshot,
        default_tax_class_name_snapshot: original.default_tax_class_name_snapshot,
        merchandise_snapshot: original.merchandise_snapshot.deep_dup,
        return_reason_code: @reason_code,
        return_reason_name_snapshot: reason_name,
        return_reason_note: @reason_note
      )
      line.save!
      line
    end

    def replace_tax_components!(line, allocation)
      line.pos_line_tax_components.delete_all
      allocation.components.each do |component|
        line.pos_line_tax_components.create!(
          store_tax_id: component.store_tax_id,
          store_tax_code_snapshot: component.store_tax_code_snapshot,
          store_tax_name_snapshot: component.store_tax_name_snapshot,
          rate_percent: component.rate_percent,
          applies: component.applies,
          taxable_basis_cents: component.taxable_basis_cents,
          tax_cents: component.tax_cents,
          calculation_order: component.calculation_order
        )
      end
    end

    def next_line_number(transaction)
      (transaction.pos_transaction_lines.maximum(:line_number) || 0) + 1
    end

    def record_added_audit!(transaction, line, original)
      Audit::Recorder.record!(
        action: "pos.linked_return.added",
        outcome: "succeeded",
        actor_user: @actor,
        actor_label: @actor.display_name,
        store: transaction.store,
        register: transaction.register,
        subject: line,
        after_values: {
          original_transaction_line_id: original.id,
          quantity: line.quantity,
          return_reason_code: line.return_reason_code
        }
      )
    end
  end
end
