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
      verify_return_keys!
      verify_return_arithmetic!
      verify_origin_name!
      verify_tenders!
      verify_controlled_actions!
      verify_line_pricing_keys!
      verify_unlinked_return_facts!
    end

    private

    V2_TENDER_KEYS = %w[behavioral_category tender_name tender_number].freeze

    RETURN_TOTAL_KEYS = %w[return_subtotal_cents return_discount_cents return_tax_cents return_total_cents].freeze

    def verify_return_keys!
      transaction = @envelope.fetch("transaction")
      present = RETURN_TOTAL_KEYS.select { |key| transaction.key?(key) }
      lines = @envelope["lines"]
      has_return_line = lines.is_a?(Array) && lines.any? { |line| line.is_a?(Hash) && line["direction"] == "return" }
      if has_return_line || present.any?
        raise Pos::Error, "completed envelope is missing return totals" unless present.size == RETURN_TOTAL_KEYS.size
        RETURN_TOTAL_KEYS.each do |key|
          raise Pos::Error, "completed envelope is missing #{key}" unless transaction[key].is_a?(Integer)
        end
      end
      raise Pos::Error, "completed envelope cannot include sale_total_cents" if transaction.key?("sale_total_cents")
      if @envelope.dig("corrections", "return_of_transaction_id").present?
        raise Pos::Error, "completed envelope cannot include corrections.return_of_transaction_id"
      end
      return unless lines.is_a?(Array)

      lines.each do |line|
        next unless line.is_a?(Hash) && line["direction"] == "return"
        next if line["post_void_source_line_id"].present?

        reason = line["return_reason"]
        raise Pos::Error, "completed envelope is missing return_reason" unless reason.is_a?(Hash)
        raise Pos::Error, "completed envelope is missing return reason code" if reason["code"].blank?
        raise Pos::Error, "completed envelope is missing return reason name" if reason["name"].blank?
      end
      verify_corrections!
    end

    def verify_corrections!
      corrections = @envelope["corrections"]
      return if corrections.nil?

      raise Pos::Error, "completed envelope corrections are invalid" unless corrections.is_a?(Hash)
      if corrections["return_of_transaction_id"].present?
        raise Pos::Error, "completed envelope cannot include corrections.return_of_transaction_id"
      end
      post_void_id = corrections["post_void_of_transaction_id"]
      original_id = corrections["original_transaction_id"]
      if post_void_id.present?
        raise Pos::Error, "completed envelope is missing post_void_of_transaction_id" if post_void_id.blank?
        raise Pos::Error, "completed envelope is missing original_transaction_id" if original_id.blank?
      elsif original_id.present?
        raise Pos::Error, "completed envelope corrections are invalid"
      end
    end

    def verify_return_arithmetic!
      transaction = @envelope.fetch("transaction")
      return unless RETURN_TOTAL_KEYS.all? { |key| transaction.key?(key) }

      subtotal = required_integer!(transaction, "subtotal_cents")
      discount = optional_integer!(transaction, "discount_cents")
      tax = required_integer!(transaction, "tax_cents")
      return_subtotal = required_integer!(transaction, "return_subtotal_cents")
      return_discount = required_integer!(transaction, "return_discount_cents")
      return_tax = required_integer!(transaction, "return_tax_cents")
      return_total = required_integer!(transaction, "return_total_cents")
      signed_net = required_integer!(transaction, "signed_net_cents")
      total = required_integer!(transaction, "total_cents")

      computed_return_total = return_subtotal - return_discount + return_tax
      unless return_total == computed_return_total
        raise Pos::Error, "completed envelope return_total_cents is invalid"
      end

      sale_total = subtotal - discount + tax
      unless signed_net == sale_total - return_total
        raise Pos::Error, "completed envelope signed_net_cents is invalid"
      end
      unless total == signed_net.abs
        raise Pos::Error, "completed envelope total_cents is invalid"
      end
    end

    def required_integer!(hash, key)
      value = hash[key]
      raise Pos::Error, "completed envelope is missing #{key}" unless value.is_a?(Integer)

      value
    end

    def optional_integer!(hash, key)
      return 0 unless hash.key?(key)

      required_integer!(hash, key)
    end

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
        if category == "cash" && tender["direction"] == "refund"
          raise Pos::Error, "presented is only for Cash payments" if tender.key?("amount_presented_cents")
          raise Pos::Error, "change is only for Cash payments" if tender.key?("change_cents")
        elsif category == "cash"
          raise Pos::Error, "completed envelope is missing Cash presented" unless tender["amount_presented_cents"].is_a?(Integer)
          raise Pos::Error, "completed envelope is missing Cash change" unless tender["change_cents"].is_a?(Integer)
        else
          raise Pos::Error, "presented is only for Cash" if tender.key?("amount_presented_cents")
          raise Pos::Error, "change is only for Cash" if tender.key?("change_cents")
        end
      end
    end

    def verify_controlled_actions!
      return unless @envelope.key?("controlled_actions")

      actions = @envelope["controlled_actions"]
      raise Pos::Error, "completed envelope controlled_actions is invalid" unless actions.is_a?(Array)

      actions.each do |action|
        raise Pos::Error, "completed envelope controlled action is invalid" unless action.is_a?(Hash)
        %w[action performed_by_user_id performed_by_name fingerprint executed_at].each do |key|
          raise Pos::Error, "completed envelope is missing #{key}" if action[key].blank?
        end
        subject = action["subject"]
        if action["action"] == "post_void"
          if subject.is_a?(Hash) && subject["line_id"].present?
            raise Pos::Error, "post_void cannot include subject line_id"
          end
        else
          raise Pos::Error, "completed envelope is missing subject line_id" unless subject.is_a?(Hash) && subject["line_id"].present?
        end
        reason = action["reason"]
        raise Pos::Error, "completed envelope is missing reason" unless reason.is_a?(Hash)
        raise Pos::Error, "completed envelope is missing reason code" if reason["code"].blank?
        raise Pos::Error, "completed envelope is missing reason name" if reason["name"].blank?
        policy = action["policy_context"]
        raise Pos::Error, "completed envelope is missing policy_context" unless policy.is_a?(Hash)
        result = policy["result"]
        raise Pos::Error, "completed envelope policy result is invalid" unless %w[direct approval_required].include?(result)
        raise Pos::Error, "completed envelope is missing policy version" if policy["version"].blank?
        material = action["material_values"]
        raise Pos::Error, "completed envelope is missing material_values" unless material.is_a?(Hash) && material.any?
        if result == "approval_required"
          raise Pos::Error, "completed envelope is missing approved_by_user_id" if action["approved_by_user_id"].blank?
          raise Pos::Error, "completed envelope is missing approved_by_name" if action["approved_by_name"].blank?
        elsif action.key?("approved_by_user_id") || action.key?("approved_by_name")
          raise Pos::Error, "direct controlled action cannot include approved_by"
        end
      end
    end

    def verify_line_pricing_keys!
      lines = @envelope["lines"]
      return unless lines.is_a?(Array)

      lines.each do |line|
        next unless line.is_a?(Hash)

        unlinked = line["direction"] == "return" && line["original_transaction_line_id"].blank? &&
                   line["post_void_source_line_id"].blank?
        if unlinked
          raise Pos::Error, "completed envelope cannot include override" if line.key?("override")
          raise Pos::Error, "completed envelope cannot include discount" if line.key?("discount")
        end
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
        verify_return_price_adjustment_shape!(line)
      end
    end

    def verify_return_price_adjustment_shape!(line)
      return if line["post_void_source_line_id"].present?

      adjustment = line["return_price_adjustment"]
      sale = line["direction"] != "return"
      linked = line["direction"] == "return" && line["original_transaction_line_id"].present?
      if sale || linked
        raise Pos::Error, "completed envelope cannot include return_price_adjustment" if line.key?("return_price_adjustment")
        return
      end
      return unless line["direction"] == "return"

      reference = line["reference_unit_price_cents"]
      selling = line["selling_unit_price_cents"]
      return unless reference.is_a?(Integer) && selling.is_a?(Integer)

      if selling == reference
        raise Pos::Error, "completed envelope cannot include return_price_adjustment" if line.key?("return_price_adjustment")
        return
      end

      raise Pos::Error, "completed envelope is missing return_price_adjustment" unless adjustment.is_a?(Hash)
      %w[reference_unit_price_cents resulting_unit_price_cents unit_variance_cents line_variance_cents].each do |key|
        raise Pos::Error, "completed envelope is missing #{key}" unless adjustment[key].is_a?(Integer)
      end
      unit_variance = selling - reference
      unless adjustment["reference_unit_price_cents"] == reference &&
             adjustment["resulting_unit_price_cents"] == selling &&
             adjustment["unit_variance_cents"] == unit_variance &&
             adjustment["line_variance_cents"] == unit_variance * line["quantity"].to_i
        raise Pos::Error, "completed envelope return_price_adjustment is invalid"
      end
    end

    def verify_unlinked_return_facts!
      lines = @envelope["lines"]
      return unless lines.is_a?(Array)

      actions = @envelope["controlled_actions"]
      actions = [] unless actions.is_a?(Array)
      actions = actions.select { |action| action.is_a?(Hash) }

      lines.each do |line|
        next unless line.is_a?(Hash)

        line_id = line["line_id"].to_s
        targeting = actions.select { |action| action.dig("subject", "line_id").to_s == line_id }
        if line["post_void_source_line_id"].present?
          raise Pos::Error, "completed envelope cannot include return_reason" if line.key?("return_reason")
          raise Pos::Error, "completed envelope cannot include original_transaction_line_id" if line["original_transaction_line_id"].present?
          next
        end

        if line["direction"] == "return" && line["original_transaction_line_id"].blank?
          unlinked_matches = targeting.select { |action| action["action"] == "unlinked_return" }
          raise Pos::Error, "completed envelope is missing unlinked_return action" unless unlinked_matches.one?
          unless targeting.one?
            raise Pos::Error, "completed envelope cannot include other controlled actions on an unlinked return"
          end
        elsif targeting.any? { |action| action["action"] == "unlinked_return" }
          raise Pos::Error, "completed envelope cannot include unlinked_return action"
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
