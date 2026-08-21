# frozen_string_literal: true

module Products
  class Create
    class Error < StandardError; end

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(attributes:, actor:, industry_identifier: nil, lookup_code: nil, source: "ui")
      attrs = attributes.to_h.symbolize_keys
      @industry_identifier = industry_identifier.presence || attrs[:industry_identifier].presence
      @lookup_code = lookup_code.presence || attrs[:lookup_code].presence
      @attributes = attrs.except(:primary_identifier, :industry_identifier, :lookup_code)
      @actor = actor
      @source = source
    end

    def call
      Product.transaction do
        primary = allocate_222!
        industry = normalized_industry(primary)

        product = Product.new(
          @attributes.merge(
            primary_identifier: primary,
            industry_identifier: industry,
            lookup_code: @lookup_code
          )
        )
        product.identifier_writes_enabled = true
        product.save!

        Identifiers::Registry.reserve!(value: primary, kind: "product_primary", product: product)
        Identifiers::Registry.reserve!(value: industry, kind: "product_industry", product: product) if industry

        Audit::Recorder.record!(
          action: "products.create",
          outcome: "succeeded",
          actor_user: @actor,
          actor_label: @actor.display_name,
          subject: product,
          after_values: {
            name: product.name,
            primary_identifier: product.primary_identifier,
            industry_identifier: product.industry_identifier,
            lookup_code: product.lookup_code,
            source: @source
          }
        )

        product
      end
    rescue Identifiers::NormalizationError, Identifiers::Registry::ConflictError, Identifiers::Generator::ExhaustedError, ActiveRecord::RecordInvalid => e
      raise Error, e.message
    end

    private

    def normalized_industry(primary)
      return if @industry_identifier.blank?

      value = Identifiers::Normalizer.normalize(@industry_identifier, allow_shelfsense_222: false)
      raise Error, "industry identifier cannot equal the primary identifier" if value == primary

      value
    end

    def allocate_222!
      attempts = 0
      begin
        attempts += 1
        value = Identifiers::Generator.next_ean13!("222")
        return value unless Identifiers::Registry.find_any(value) || Product.exists?(primary_identifier: value)

        raise Identifiers::Registry::ConflictError, "generated identifier collision" if attempts < 5

        raise Identifiers::Registry::ConflictError, "unable to allocate unique 222 identifier"
      rescue Identifiers::Registry::ConflictError
        retry if attempts < 5
        raise
      end
    end
  end
end
