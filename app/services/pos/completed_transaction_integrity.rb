# frozen_string_literal: true

module Pos
  class CompletedTransactionIntegrity
    def self.verify!(transaction)
      new(transaction).verify!
    end

    def initialize(transaction)
      @transaction = transaction
    end

    def verify!
      verify_post_void_transaction!
      @transaction.pos_transaction_lines.each do |line|
        actions = line.pos_controlled_actions.index_by(&:action_type)
        if line.post_void_generated?
          raise Pos::Error, "post-void lines cannot have controlled actions" if actions.any?
          next
        end
        if line.linked_return?
          raise Pos::Error, "return lines cannot have controlled actions" if actions.any?
          next
        end
        if line.unlinked_return?
          verify_unlinked!(line, actions)
          next
        end

        verify_pair!(
          present: line.price_overridden?,
          action: actions["price_override"],
          message: "price override fact does not match selling price"
        )
        verify_pair!(
          present: line.manually_discounted?,
          action: actions["line_discount"],
          message: "line discount fact does not match discount"
        )
        verify_pair!(
          present: line.tax_class_overridden?,
          action: actions["tax_class_override"],
          message: "Tax Class override fact does not match applied class"
        )
        actions.each_value { |action| verify_fingerprint!(line, action) }
      end
    end

    private

    def verify_post_void_transaction!
      actions = @transaction.pos_controlled_actions.where(action_type: "post_void")
      if @transaction.post_void?
        raise Pos::Error, "post-void is missing the post_void fact" unless actions.one?
        action = actions.first
        raise Pos::Error, "post_void cannot target a line" if action.pos_transaction_line_id.present?
      elsif actions.exists?
        raise Pos::Error, "ordinary transactions cannot include post_void"
      end
    end

    def verify_unlinked!(line, actions)
      if actions.key?("price_override") || actions.key?("line_discount") || actions.key?("tax_class_override")
        raise Pos::Error, "unlinked returns cannot have sale controlled actions"
      end
      action = actions["unlinked_return"]
      raise Pos::Error, "unlinked return is missing the unlinked_return fact" if action.nil?
      raise Pos::Error, "unlinked return must have exactly one controlled action" if actions.size != 1
      if line.manual_discount_basis_points.present? || line.manual_discount_cents.to_i != 0
        raise Pos::Error, "unlinked returns cannot have a sale discount"
      end
      if line.return_reason_code != action.reason_code ||
         line.return_reason_name_snapshot != action.reason_name_snapshot ||
         line.return_reason_note.to_s != action.reason_note.to_s
        raise Pos::Error, "unlinked return reason does not match the approved fact"
      end
      expected_name = Pos::ReturnReasons.name_for!(line.return_reason_code)
      unless line.return_reason_name_snapshot == expected_name
        raise Pos::Error, "unlinked return reason does not match the approved fact"
      end

      verify_fingerprint!(line, action)
    end

    def verify_pair!(present:, action:, message:)
      raise Pos::Error, message if present ^ action.present?
    end

    def verify_fingerprint!(line, action)
      material = reconstructed_material(line, action)
      stored = Idempotency::CanonicalJson.normalize(action.material_values)
      expected_material = Idempotency::CanonicalJson.normalize(material)
      raise Pos::Error, "controlled action material values do not match" unless stored == expected_material

      reason_code, reason_note = fingerprint_reason(line, action)
      expected = Pos::ControlledActionFingerprint.call(
        action_type: action.action_type,
        transaction_id: line.pos_transaction_id,
        line_id: line.id,
        material_values: material,
        reason_code: reason_code,
        reason_note: reason_note
      )
      raise Pos::Error, "controlled action fingerprint does not match" unless expected == action.action_fingerprint
    end

    def fingerprint_reason(line, action)
      if action.action_type == "unlinked_return"
        [ line.return_reason_code, line.return_reason_note ]
      else
        [ action.reason_code, action.reason_note ]
      end
    end

    def reconstructed_material(line, action)
      case action.action_type
      when "price_override"
        {
          "reference_unit_price_cents" => line.reference_unit_price_cents,
          "requested_selling_unit_price_cents" => line.selling_unit_price_cents,
          "quantity" => line.quantity
        }
      when "line_discount"
        {
          "selling_unit_price_cents" => line.selling_unit_price_cents,
          "quantity" => line.quantity,
          "line_selling_basis_cents" => line.selling_unit_price_cents * line.quantity,
          "discount_basis_points" => line.manual_discount_basis_points
        }
      when "tax_class_override"
        {
          "default_tax_class_id" => line.default_tax_class_id.to_s,
          "requested_tax_class_id" => line.tax_class_id.to_s
        }
      when "unlinked_return"
        values = {
          "product_variant_id" => line.product_variant_id.to_s,
          "quantity" => line.quantity,
          "reference_unit_price_cents" => line.reference_unit_price_cents,
          "requested_return_unit_price_cents" => line.selling_unit_price_cents,
          "tax_class_id" => line.tax_class_id.to_s
        }
        values["inventory_unit_id"] = line.inventory_unit_id.to_s if line.inventory_unit_id.present?
        values
      end
    end
  end
end
