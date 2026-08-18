# frozen_string_literal: true

module Pos
  class CompletedTransactionFacts
    def initialize(envelope)
      @envelope = Idempotency::CanonicalJson.normalize(envelope)
      freeze
    end

    attr_reader :envelope

    def envelope_hash
      Idempotency::CanonicalJson.hash(@envelope)
    end

    def receipt_sequence
      @envelope.fetch("receipt").fetch("sequence")
    end

    def store_number
      @envelope.fetch("receipt").fetch("store_number")
    end

    def register_number
      @envelope.fetch("receipt").fetch("register_number")
    end

    def transaction_reference
      @envelope.fetch("receipt").fetch("reference")
    end

    def occurred_at
      @envelope.fetch("transaction").fetch("occurred_at")
    end

    def business_date
      @envelope.fetch("transaction").fetch("business_date")
    end

    def verify!
      receipt = @envelope.fetch("receipt")
      raise Pos::Error, "completed envelope is missing receipt sequence" unless positive_integer?(receipt["sequence"])
      raise Pos::Error, "completed envelope is missing receipt reference" if receipt["reference"].blank?
      raise Pos::Error, "completed envelope is missing store number" unless positive_integer?(receipt["store_number"])
      raise Pos::Error, "completed envelope is missing register number" unless positive_integer?(receipt["register_number"])
      raise Pos::Error, "completed envelope fact_type is invalid" unless @envelope.dig("operation", "fact_type") == PosOperation::FACT_TYPE
      version = @envelope.fetch("schema_version")
      raise Pos::Error, "completed envelope schema_version is invalid" unless [ 1, 2 ].include?(version)
      return unless version == 2

      signed_net = @envelope.fetch("transaction")["signed_net_cents"]
      raise Pos::Error, "completed envelope is missing signed_net_cents" unless signed_net.is_a?(Integer)
      verify_origin_name!
      verify_tenders!
      verify_controlled_actions!
      verify_line_pricing_keys!
    end

    private

    V2_TENDER_KEYS = %w[behavioral_category tender_name tender_number].freeze

    def verify_origin_name!
      origin = @envelope["origin"]
      return unless origin.is_a?(Hash)
      return unless origin.key?("performed_by_name")
      raise Pos::Error, "completed envelope is missing performed_by_name" if origin["performed_by_name"].blank?
    end

    def verify_tenders!
      tenders = @envelope["tenders"]
      return unless tenders.is_a?(Array)
      return unless tenders.any? { |tender| v2_tender_shape?(tender) }

      tenders.each do |tender|
        raise Pos::Error, "completed envelope tender is missing 6.2 keys" unless v2_tender_shape?(tender)
        V2_TENDER_KEYS.each do |key|
          raise Pos::Error, "completed envelope is missing #{key}" if tender[key].blank? && tender[key] != 0
        end
        raise Pos::Error, "completed envelope tender_number is invalid" unless positive_integer?(tender["tender_number"])
        category = tender["behavioral_category"]
        raise Pos::Error, "completed envelope behavioral_category is invalid" unless TenderType::CATEGORIES.include?(category)
        if category == "cash"
          raise Pos::Error, "completed envelope is missing Cash presented" unless tender["amount_presented_cents"].is_a?(Integer)
          raise Pos::Error, "completed envelope is missing Cash change" unless tender["change_cents"].is_a?(Integer)
        else
          raise Pos::Error, "presented is only for Cash" if tender.key?("amount_presented_cents")
          raise Pos::Error, "change is only for Cash" if tender.key?("change_cents")
        end
      end
    end

    def verify_controlled_actions!
      actions = @envelope["controlled_actions"]
      return unless actions.is_a?(Array)

      actions.each do |action|
        raise Pos::Error, "completed envelope controlled action is invalid" unless action.is_a?(Hash)
        %w[action performed_by_user_id performed_by_name fingerprint].each do |key|
          raise Pos::Error, "completed envelope is missing #{key}" if action[key].blank?
        end
        result = action.dig("policy_context", "result")
        raise Pos::Error, "completed envelope policy result is invalid" unless %w[direct approval_required].include?(result)
        if result == "approval_required"
          raise Pos::Error, "completed envelope is missing approved_by_user_id" if action["approved_by_user_id"].blank?
        elsif action.key?("approved_by_user_id")
          raise Pos::Error, "direct controlled action cannot include approved_by"
        end
      end
    end

    def verify_line_pricing_keys!
      lines = @envelope["lines"]
      return unless lines.is_a?(Array)

      lines.each do |line|
        next unless line.is_a?(Hash)

        if line.key?("override")
          override = line["override"]
          raise Pos::Error, "completed envelope override is invalid" unless override.is_a?(Hash)
          %w[reference_unit_price_cents selling_unit_price_cents unit_variance_cents line_variance_cents].each do |key|
            raise Pos::Error, "completed envelope is missing #{key}" unless override[key].is_a?(Integer)
          end
        end
        if line.key?("discount")
          discount = line["discount"]
          raise Pos::Error, "completed envelope discount is invalid" unless discount.is_a?(Hash)
          raise Pos::Error, "completed envelope is missing discount basis_points" unless discount["basis_points"].is_a?(Integer)
          raise Pos::Error, "completed envelope is missing discount_cents" unless discount["discount_cents"].is_a?(Integer)
          raise Pos::Error, "completed envelope is missing net_merchandise_amount_cents" unless discount["net_merchandise_amount_cents"].is_a?(Integer)
        end
      end
    end

    def v2_tender_shape?(tender)
      return false unless tender.is_a?(Hash)

      V2_TENDER_KEYS.any? { |key| tender.key?(key) }
    end

    def positive_integer?(value)
      value.is_a?(Integer) && value.positive?
    end
  end
end
