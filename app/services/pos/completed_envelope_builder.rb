# frozen_string_literal: true

module Pos
  class CompletedEnvelopeBuilder
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(transaction:, actor:, operation_id:, completion_time:, business_date:, receipt:)
      @transaction = transaction
      @actor = actor
      @operation_id = operation_id
      @completion_time = completion_time
      @business_date = business_date
      @receipt = receipt
    end

    def call
      envelope = {
        "schema_version" => 3,
        "operation" => {
          "operation_id" => @operation_id.to_s,
          "fact_type" => PosOperation::FACT_TYPE
        },
        "origin" => {
          "store_id" => @transaction.store_id.to_s,
          "register_id" => @transaction.register_id.to_s,
          "pos_session_id" => @transaction.pos_session_id.to_s,
          "reporting_period_id" => @transaction.reporting_period_id.to_s,
          "performed_by_user_id" => @transaction.cashier_user_id.to_s,
          "performed_by_name" => @actor.display_name
        },
        "receipt" => {
          "sequence" => @receipt.fetch(:sequence),
          "store_number" => @receipt.fetch(:store_number),
          "register_number" => @receipt.fetch(:register_number),
          "reference" => @receipt.fetch(:reference)
        },
        "transaction" => {
          "transaction_id" => @transaction.id.to_s,
          "currency_code" => @transaction.currency_code,
          "occurred_at" => @completion_time.utc.iso8601(6),
          "business_date" => @business_date.iso8601,
          "subtotal_cents" => @transaction.subtotal_cents,
          "tax_cents" => @transaction.tax_cents,
          "total_cents" => @transaction.total_cents,
          "return_subtotal_cents" => @transaction.return_subtotal_cents,
          "return_discount_cents" => @transaction.return_discount_cents,
          "return_tax_cents" => @transaction.return_tax_cents,
          "return_total_cents" => @transaction.return_total_cents,
          "signed_net_cents" => @transaction.signed_net_cents,
          "stored_value_issuance_cents" => @transaction.stored_value_issuance_cents
        },
        "lines" => @transaction.pos_transaction_lines.reload.map { |line| envelope_line(line) },
        "tenders" => @transaction.pos_tenders.ordered.map { |tender| envelope_tender(tender) }
      }
      envelope["transaction"]["discount_cents"] = @transaction.discount_cents unless @transaction.discount_cents.zero?
      envelope["transaction"]["customer_id"] = @transaction.customer_id.to_s if @transaction.customer_id.present?
      issuances = @transaction.pos_stored_value_issuances.ordered.map { |issuance| envelope_issuance(issuance) }
      envelope["issuances"] = issuances if issuances.any?
      actions = @transaction.pos_controlled_actions.order(:executed_at, :id).map { |action| envelope_controlled_action(action) }
      envelope["controlled_actions"] = actions if actions.any?
      if @transaction.post_void?
        envelope["corrections"] = {
          "original_transaction_id" => @transaction.post_void_of_transaction_id.to_s,
          "post_void_of_transaction_id" => @transaction.post_void_of_transaction_id.to_s
        }
      end
      facts = CompletedTransactionFacts.new(envelope)
      facts.verify!
      facts
    end

    private

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
      payload["original_transaction_line_id"] = line.original_transaction_line_id.to_s if line.original_transaction_line_id.present?
      payload["post_void_source_line_id"] = line.post_void_source_line_id.to_s if line.post_void_source_line_id.present?
      if line.return? && !line.post_void_generated?
        reason = {
          "code" => line.return_reason_code,
          "name" => line.return_reason_name_snapshot
        }
        reason["note"] = line.return_reason_note if line.return_reason_note.present?
        payload["return_reason"] = reason
      end
      if emit_historical_override?(line)
        unit_variance = line.selling_unit_price_cents - line.reference_unit_price_cents
        payload["override"] = {
          "reference_unit_price_cents" => line.reference_unit_price_cents,
          "selling_unit_price_cents" => line.selling_unit_price_cents,
          "unit_variance_cents" => unit_variance,
          "line_variance_cents" => unit_variance * line.quantity
        }
      end
      if emit_return_price_adjustment?(line)
        unit_variance = line.selling_unit_price_cents - line.reference_unit_price_cents
        payload["return_price_adjustment"] = {
          "reference_unit_price_cents" => line.reference_unit_price_cents,
          "resulting_unit_price_cents" => line.selling_unit_price_cents,
          "unit_variance_cents" => unit_variance,
          "line_variance_cents" => unit_variance * line.quantity
        }
      end
      if emit_historical_discount?(line)
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

    def emit_historical_override?(line)
      if line.post_void_generated?
        source = line.post_void_source_line
        return false if source.nil?

        return source.selling_unit_price_cents != source.reference_unit_price_cents
      end
      return line.price_overridden? if line.sale?
      return false if line.unlinked_return?

      line.selling_unit_price_cents != line.reference_unit_price_cents
    end

    def emit_return_price_adjustment?(line)
      line.unlinked_return? && line.selling_unit_price_cents != line.reference_unit_price_cents
    end

    def emit_historical_discount?(line)
      if line.post_void_generated?
        source = line.post_void_source_line
        return false if source.nil?

        return source.manual_discount_cents.to_i.positive? || source.manual_discount_basis_points.present?
      end
      return line.manually_discounted? if line.sale?
      return false if line.unlinked_return?

      line.manual_discount_cents.to_i.positive? || line.manual_discount_basis_points.present?
    end

    def envelope_controlled_action(action)
      payload = {
        "action" => action.action_type,
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
      if action.pos_transaction_line_id.present?
        payload["subject"] = { "line_id" => action.pos_transaction_line_id.to_s }
      end
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
      if tender.cash? && tender.direction == "payment"
        payload["amount_presented_cents"] = tender.amount_presented_cents
        payload["change_cents"] = tender.change_cents
      end
      payload["external_reference"] = tender.external_reference if tender.external_reference.present?
      payload["post_void_source_tender_id"] = tender.post_void_source_tender_id.to_s if tender.post_void_source_tender_id.present?
      detail = tender.stored_value_tender_detail
      if detail
        stored_value = {
          "destination_mode" => detail.destination_mode,
          "stored_value_operation_id" => detail.stored_value_operation_id&.to_s
        }
        stored_value["stored_value_account_id"] = detail.stored_value_account_id.to_s if detail.stored_value_account_id.present?
        stored_value["gift_card_id"] = detail.gift_card_id.to_s if detail.gift_card_id.present?
        stored_value["masked_card"] = detail.masked_card_snapshot if detail.masked_card_snapshot.present?
        payload["stored_value"] = stored_value
      end
      payload
    end

    def envelope_issuance(issuance)
      payload = {
        "issuance_id" => issuance.id.to_s,
        "issuance_number" => issuance.issuance_number,
        "issuance_type" => issuance.issuance_type,
        "amount_cents" => issuance.amount_cents,
        "number_authority" => issuance.number_authority,
        "stored_value_operation_id" => issuance.stored_value_operation_id&.to_s
      }
      payload["gift_card_id"] = issuance.gift_card_id.to_s if issuance.gift_card_id.present?
      payload["gift_card_program_id"] = issuance.gift_card_program_id.to_s if issuance.gift_card_program_id.present?
      payload["masked_card"] = issuance.masked_card_snapshot if issuance.masked_card_snapshot.present?
      payload["post_void_source_issuance_id"] = issuance.post_void_source_issuance_id.to_s if issuance.post_void_source_issuance_id.present?
      payload
    end
  end
end
