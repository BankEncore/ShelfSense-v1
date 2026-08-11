# frozen_string_literal: true

module Products
  class Create
    class Error < StandardError; end

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(attributes:, actor:, identifier_mode:, external_identifier: nil, source: "ui")
      @attributes = attributes
      @actor = actor
      @identifier_mode = identifier_mode.to_s
      @external_identifier = external_identifier
      @source = source
    end

    def call
      raise Error, "identifier mode must be enter or generate" unless %w[enter generate].include?(@identifier_mode)
      raise Error, "external identifier is required" if @identifier_mode == "enter" && @external_identifier.blank?
      raise Error, "external identifier must be blank when generating" if @identifier_mode == "generate" && @external_identifier.present?

      Product.transaction do
        primary =
          if @identifier_mode == "generate"
            allocate_222!
          else
            Identifiers::Normalizer.normalize(@external_identifier, allow_shelfsense_222: false)
          end

        product = Product.new(@attributes.merge(primary_identifier: primary))
        product.identifier_writes_enabled = true
        product.save!

        Identifiers::Registry.reserve!(value: primary, kind: "product_primary", product: product)

        Audit::Recorder.record!(
          action: "products.create",
          outcome: "succeeded",
          actor_user: @actor,
          actor_label: @actor.display_name,
          subject: product,
          after_values: {
            name: product.name,
            primary_identifier: product.primary_identifier,
            identifier_source: @identifier_mode,
            source: @source
          }
        )

        product
      end
    rescue Identifiers::NormalizationError, Identifiers::Registry::ConflictError, Identifiers::Generator::ExhaustedError, ActiveRecord::RecordInvalid => e
      raise Error, e.message
    end

    private

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
