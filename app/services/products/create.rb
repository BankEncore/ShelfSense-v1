# frozen_string_literal: true

module Products
  class Create
    class Error < StandardError; end

    VIRTUAL_KEYS = %i[contribution_rows subject_rows bibliographic_field_sources cover_image cover_download].freeze
    REJECT_KEYS = %i[cover_image_url publisher_id publisher_name edition publication_year binding].freeze

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(attributes:, actor:, industry_identifier: nil, lookup_code: nil, source: "ui",
                   bibliographic_field_sources: nil)
      attrs = attributes.to_h.symbolize_keys
      @industry_identifier = industry_identifier.presence || attrs[:industry_identifier].presence
      @lookup_code = lookup_code.presence || attrs[:lookup_code].presence
      @contribution_rows = attrs[:contribution_rows]
      @subject_rows = attrs[:subject_rows]
      @cover_image = attrs[:cover_image]
      @cover_download = attrs[:cover_download]
      @provided_sources = bibliographic_field_sources || attrs[:bibliographic_field_sources]
      @attributes = attrs.except(
        :primary_identifier, :industry_identifier, :lookup_code, *VIRTUAL_KEYS, *REJECT_KEYS
      )
      map_legacy_publisher!(attrs)
      @attributes[:release_date_approximate] = ActiveModel::Type::Boolean.new.cast(@attributes[:release_date_approximate]) == true
      @attributes[:status] = @attributes[:status].to_s.strip.presence || "active"
      @actor = actor
      @source = source
      @attached_blob = nil
    end

    def call
      committed = false
      product = Product.transaction do
        primary = allocate_222!
        industry = normalized_industry(primary)
        sources = provenance_document(industry)

        product = Product.new(
          @attributes.merge(
            primary_identifier: primary,
            industry_identifier: industry,
            lookup_code: @lookup_code,
            bibliographic_field_sources: sources
          )
        )
        product.identifier_writes_enabled = true
        product.save!

        Identifiers::Registry.reserve!(value: primary, kind: "product_primary", product: product)
        Identifiers::Registry.reserve!(value: industry, kind: "product_industry", product: product) if industry
        if @contribution_rows
          Products::AssignContributions.call(product: product, rows: @contribution_rows)
        end
        if @subject_rows
          Products::AssignSubjects.call(product: product, rows: @subject_rows)
        end
        attach_cover!(product)

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
            bibliographic_provider: product.bibliographic_provider,
            source: @source
          }
        )
        if product.bibliographic_provider.present?
          Audit::Recorder.record!(
            action: "products.enrich",
            outcome: "succeeded",
            actor_user: @actor,
            actor_label: @actor.display_name,
            subject: product,
            after_values: {
              bibliographic_provider: product.bibliographic_provider,
              bibliographic_provider_key: product.bibliographic_provider_key,
              applied_fields: product.bibliographic_field_sources.keys
            }
          )
        end

        product
      end
      committed = true
      product
    rescue Identifiers::NormalizationError, Identifiers::Registry::ConflictError, Identifiers::Generator::ExhaustedError,
           ActiveRecord::RecordInvalid, ArgumentError, Bibliographic::FieldSources::Invalid,
           Bibliographic::ContributorRole::Unknown, Products::AssignSubjects::Error,
           Bibliographic::CoverDownloader::Error, Bibliographic::CoverPayload::Error => e
      raise Error, e.message
    ensure
      @attached_blob&.purge unless committed
    end

    private

    def map_legacy_publisher!(attrs)
      return if @attributes[:brand_name].present?
      return if attrs[:publisher_name].blank?

      @attributes[:brand_name] = attrs[:publisher_name].to_s.strip.presence
    end

    def provenance_document(industry)
      if @provided_sources.present?
        return Bibliographic::FieldSources.validate!(@provided_sources)
      end

      Bibliographic::FieldSources.staff_for_populated(
        @attributes.merge(industry_identifier: industry),
        contribution_rows: @contribution_rows,
        subject_rows: @subject_rows,
        cover_attached: @cover_image.present? || @cover_download.present?
      )
    end

    def attach_cover!(product)
      if @cover_download
        attach_blob!(product, @cover_download.bytes, @cover_download.filename, @cover_download.content_type)
      elsif @cover_image.present?
        payload = Bibliographic::CoverPayload.from_upload(@cover_image)
        attach_blob!(product, payload.bytes, payload.filename, payload.content_type)
      end
    end

    def attach_blob!(product, bytes, filename, content_type)
      @attached_blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(bytes),
        filename: filename,
        content_type: content_type
      )
      product.cover_image.attach(@attached_blob)
    end

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
