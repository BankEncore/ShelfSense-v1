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
      @transaction.pos_transaction_lines.each do |line|
        actions = line.pos_controlled_actions.index_by(&:action_type)
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

    def verify_pair!(present:, action:, message:)
      raise Pos::Error, message if present ^ action.present?
    end

    def verify_fingerprint!(line, action)
      material = reconstructed_material(line, action)
      stored = Idempotency::CanonicalJson.normalize(action.material_values)
      expected_material = Idempotency::CanonicalJson.normalize(material)
      raise Pos::Error, "controlled action material values do not match" unless stored == expected_material

      expected = Pos::ControlledActionFingerprint.call(
        action_type: action.action_type,
        transaction_id: line.pos_transaction_id,
        line_id: line.id,
        material_values: material,
        reason_code: action.reason_code,
        reason_note: action.reason_note
      )
      raise Pos::Error, "controlled action fingerprint does not match" unless expected == action.action_fingerprint
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
      end
    end
  end
end
