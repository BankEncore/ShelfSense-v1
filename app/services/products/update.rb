# frozen_string_literal: true

module Products
  class Update
    class Error < StandardError; end

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(product:, attributes:, actor:, source: "ui", store: nil)
      @product = product
      attrs = attributes.to_h.symbolize_keys
      @lock_version = attrs[:lock_version]
      @attributes = attrs.except(:primary_identifier, :lock_version)
      @actor = actor
      @source = source
      @store = store
    end

    def call
      Product.transaction do
        before = @product.attributes.slice(*audit_keys)
        @product.lock_version = @lock_version unless @lock_version.nil?

        if @attributes.key?(:industry_identifier)
          Identifiers::AssignProductIndustry.call(
            product: @product,
            raw_value: @attributes[:industry_identifier],
            actor: @actor,
            source: @source,
            persist: false
          )
        end

        non_id_attrs = @attributes.except(:industry_identifier)
        @product.assign_attributes(non_id_attrs) if non_id_attrs.any?
        @product.save!

        Audit::Recorder.record!(
          action: "products.update",
          outcome: "succeeded",
          actor_user: @actor,
          actor_label: @actor.display_name,
          store: @store,
          subject: @product,
          before_values: before,
          after_values: @product.attributes.slice(*before.keys).merge(source: @source)
        )
        @product
      end
    rescue Identifiers::AssignProductIndustry::Error, ActiveRecord::RecordInvalid => e
      raise Error, e.message
    end

    private

    def audit_keys
      %w[
        name subtitle description brand_name product_model merchandise_category_id
        list_price_cents release_date status variant_option_name_1 variant_option_name_2
        industry_identifier lookup_code
      ]
    end
  end
end
