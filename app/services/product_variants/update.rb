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
      @attributes = attrs.except(:sku, :lock_version)
      @actor = actor
      @source = source
      @store = store
    end

    def call
      ProductVariant.transaction do
        before = @variant.attributes.slice(*audit_keys)
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
          after_values: @variant.attributes.slice(*before.keys).merge(source: @source)
        )

        @variant
      end
    rescue Identifiers::AssignIndustry::Error, ActiveRecord::RecordInvalid => e
      raise Error, e.message
    end

    private

    def audit_keys
      %w[
        variant_type name option_value_1 option_value_2 merchandise_condition_id merchandise_class_id
        department_id tax_class_id regular_price_cents status industry_identifier
      ]
    end
  end
end
