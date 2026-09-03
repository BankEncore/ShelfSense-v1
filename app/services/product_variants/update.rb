# frozen_string_literal: true

module ProductVariants
  class Update
    class Error < StandardError; end

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(variant:, attributes:, actor:, source: "ui", store: nil)
      @variant = variant
      attrs = attributes.to_h.symbolize_keys
      @lock_version = attrs[:lock_version]
      @attributes = attrs.except(:sku, :lock_version, :department_id, :tax_class_id, :name)
      if @attributes.key?(:status)
        @attributes[:status] = @attributes[:status].to_s.strip.presence || "active"
      end
      @actor = actor
      @source = source
      @store = store
    end

    def call
      ProductVariant.transaction do
        before = snapshot_for_audit
        @variant.lock_version = @lock_version unless @lock_version.nil?

        if @attributes.key?(:industry_identifier)
          Identifiers::AssignIndustry.call(
            variant: @variant,
            raw_value: @attributes[:industry_identifier],
            actor: @actor,
            source: @source,
            persist: false
          )
        end

        non_id_attrs = @attributes.except(:industry_identifier)
        @variant.assign_attributes(non_id_attrs) if non_id_attrs.any?
        @variant.save!

        Audit::Recorder.record!(
          action: "product_variants.update",
          outcome: "succeeded",
          actor_user: @actor,
          actor_label: @actor.display_name,
          store: @store,
          subject: @variant,
          before_values: before,
          after_values: snapshot_for_audit.merge("source" => @source)
        )

        @variant
      end
    rescue Identifiers::AssignIndustry::Error, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
      raise Error, e.message
    end

    private

    def snapshot_for_audit
      {
        "variant_type" => @variant.variant_type,
        "name" => @variant.name,
        "option_value_1" => @variant.option_value_1,
        "option_value_2" => @variant.option_value_2,
        "merchandise_condition_id" => @variant.merchandise_condition_id,
        "merchandise_class_id" => @variant.merchandise_class_id,
        "inventory_mode" => @variant.inventory_mode,
        "pricing_method" => @variant.pricing_method,
        "target_margin_bps" => @variant.target_margin_bps,
        "supplier_returnable" => @variant.supplier_returnable,
        "tax_class_override_id" => @variant.tax_class_override_id,
        "effective_tax_class_id" => @variant.effective_tax_class&.id,
        "regular_price_cents" => @variant.regular_price_cents,
        "status" => @variant.status,
        "industry_identifier" => @variant.industry_identifier
      }
    end
  end
end
