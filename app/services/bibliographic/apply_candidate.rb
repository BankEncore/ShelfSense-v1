# frozen_string_literal: true

module Bibliographic
  class ApplyCandidate
    class Error < StandardError; end

    COMPARABLE_FIELDS = %w[
      name subtitle description brand_name imprint product_model language_code
      page_count series_name series_position release_date list_price_cents
      industry_identifier
    ].freeze

    COLLECTION_FIELDS = %w[contributions product_form cover_image subjects].freeze

    def self.call(**attrs)
      new(**attrs).call
    end

    attr_reader :applied_fields

    def initialize(product:, candidate:, actor:, selected_fields:, submitted_values: {}, source: "bibliographic",
                   lock_version: nil, store: nil)
      @product = product
      @candidate = candidate
      @actor = actor
      @selected_fields = Array(selected_fields).map(&:to_s)
      @submitted_values = submitted_values.to_h
      @source = source
      @lock_version = lock_version
      @store = store
      @applied_fields = []
    end

    def call
      raise Error, "select at least one field to apply" if @selected_fields.empty?

      unknown = @selected_fields - (COMPARABLE_FIELDS + COLLECTION_FIELDS)
      raise Error, "unknown selected field #{unknown.join(', ')}" if unknown.any?

      cover_result = nil
      Product.transaction do
        attrs = {}
        provenance = []
        @selected_fields.each do |field|
          next if %w[contributions cover_image subjects product_form].include?(field)

          value, edited = resolved_value(field)
          attrs[field.to_sym] = value
          if field == "release_date"
            attrs[:release_date_approximate] = edited ? submitted_approximate : @candidate.release_date_approximate
          end
          provenance << provenance_change(field, edited, value: value)
          @applied_fields << field
        end

        if @selected_fields.include?("product_form")
          code, edited = resolved_value("product_form")
          attrs[:product_form_id] = product_form_id_for(code)
          provenance << provenance_change("product_form", edited, value: code)
          @applied_fields << "product_form"
        end

        contribution_rows = nil
        if @selected_fields.include?("contributions")
          contribution_rows, edited = resolved_contributions
          provenance << provenance_change("contributions", edited, rows: contribution_rows)
          @applied_fields << "contributions"
        end

        subject_rows = nil
        if @selected_fields.include?("subjects")
          subject_rows, edited = resolved_subjects
          provenance << provenance_change("subjects", edited, rows: subject_rows)
          @applied_fields << "subjects"
        end

        if @selected_fields.include?("cover_image")
          cover_result = download_cover
          provenance << provenance_change("cover_image", false).merge(source_url: cover_result.source_url)
          @applied_fields << "cover_image"
        end

        payload = attrs.merge(
          bibliographic_provider: @candidate.provider,
          bibliographic_provider_key: @candidate.isbn13.presence || @product.bibliographic_provider_key,
          bibliographic_fetched_at: @candidate.fetched_at,
          bibliographic_applied_at: Time.current,
          lock_version: @lock_version || @product.lock_version
        )
        payload[:contribution_rows] = contribution_rows unless contribution_rows.nil?
        payload[:subject_rows] = subject_rows unless subject_rows.nil?
        payload[:cover_download] = cover_result if cover_result

        Products::Update.call(
          product: @product,
          attributes: payload,
          actor: @actor,
          source: @source,
          provenance_changes: provenance
        )
        Audit::Recorder.record!(
          action: "products.enrich",
          outcome: "succeeded",
          actor_user: @actor,
          actor_label: @actor.display_name,
          store: @store,
          subject: @product,
          after_values: {
            bibliographic_provider: @candidate.provider,
            bibliographic_provider_key: @candidate.provider_key || @candidate.isbn13,
            applied_fields: @applied_fields
          }
        )
        @product.reload
      end
    rescue Products::Update::Error, ArgumentError, Bibliographic::FieldSources::Invalid,
           Bibliographic::ContributorRole::Unknown, Bibliographic::CoverDownloader::Error,
           Bibliographic::CoverPayload::Error, Products::AssignSubjects::Error,
           ActiveRecord::StaleObjectError, Money::ParseCents::Error,
           Identifiers::NormalizationError => e
      cover_result&.then { purge_failed_cover }
      raise Error, e.message
    end

    private

    def resolved_value(field)
      candidate_value = candidate_value_for(field)
      submitted = submitted_for(field)
      if submitted.nil?
        [ candidate_value, false ]
      else
        parsed = parse_submitted(field, submitted)
        if values_equal?(parsed, candidate_value)
          [ candidate_value, false ]
        else
          [ parsed, true ]
        end
      end
    end

    def parse_submitted(field, raw)
      case field
      when "page_count" then parse_page_count(raw)
      when "list_price_cents" then parse_list_price(raw)
      when "series_position" then parse_series_position(raw)
      when "release_date" then parse_release_date(raw)
      when "industry_identifier" then parse_industry_identifier(raw)
      when "product_form" then parse_string(raw)&.upcase
      else
        parse_string(raw)
      end
    end

    def parse_page_count(raw)
      return raw if raw.is_a?(Integer)
      text = raw.to_s.strip
      return if text.blank?

      Integer(text)
    end

    def parse_list_price(raw)
      return raw if raw.is_a?(Integer)
      text = raw.to_s.strip
      return if text.blank?

      Money::ParseCents.call(text)
    end

    def parse_series_position(raw)
      return raw if raw.is_a?(BigDecimal)
      return BigDecimal(raw.to_s) if raw.is_a?(Numeric)
      text = raw.to_s.strip
      return if text.blank?

      BigDecimal(text)
    end

    def parse_release_date(raw)
      return raw if raw.is_a?(Date)
      text = raw.to_s.strip
      return if text.blank?

      Date.iso8601(text)
    end

    def parse_industry_identifier(raw)
      text = raw.to_s.strip
      return if text.blank?

      Identifiers::Normalizer.normalize(text, allow_shelfsense_222: false)
    end

    def parse_string(raw)
      return if raw.nil?

      text = raw.to_s.unicode_normalize(:nfkc).strip.gsub(/\s+/, " ")
      text.presence
    end

    def resolved_contributions
      submitted = @submitted_values[:contribution_rows] || @submitted_values["contribution_rows"]
      candidate_rows = @candidate.contribution_rows
      if submitted.nil?
        [ candidate_rows, false ]
      elsif contribution_signature(submitted) == contribution_signature(candidate_rows)
        [ candidate_rows, false ]
      else
        [ submitted, true ]
      end
    end

    def resolved_subjects
      candidate_rows = Bibliographic::SubjectMatcher.rows_for(@candidate.subjects)
      submitted = @submitted_values[:subject_rows] || @submitted_values["subject_rows"]
      if submitted.nil?
        [ candidate_rows, false ]
      elsif subject_signature(submitted) == subject_signature(candidate_rows)
        [ candidate_rows, false ]
      else
        [ submitted, true ]
      end
    end

    def candidate_value_for(field)
      case field
      when "name" then @candidate.title
      when "brand_name" then @candidate.publisher_name
      when "product_model" then @candidate.edition
      when "industry_identifier" then @candidate.isbn13
      when "product_form" then @candidate.product_form_code
      else
        @candidate.product_attributes[field.to_sym]
      end
    end

    def submitted_for(field)
      return unless @submitted_values.key?(field.to_sym) || @submitted_values.key?(field)

      @submitted_values[field.to_sym] || @submitted_values[field]
    end

    def submitted_approximate
      raw = submitted_for("release_date_approximate")
      return false if raw.nil?

      ActiveModel::Type::Boolean.new.cast(raw)
    end

    def product_form_id_for(code)
      return if code.blank?

      form = ProductForm.find_by(code: code.to_s.strip.upcase)
      raise Error, "unknown product form" if form.nil?
      if !form.assignable? && form.id != @product.product_form_id
        raise Error, "must be an active product form"
      end

      form.id
    end

    def download_cover
      url = @candidate.cover_image_url
      raise Error, "candidate has no cover URL" if url.blank?

      submitted = submitted_for("cover_image")
      if submitted.present? && !values_equal?(submitted, url)
        raise Error, "Cover URL cannot be edited during review; upload a replacement on the product instead."
      end

      CoverDownloader.call(url: url, allowed_urls: [ url ])
    end

    def purge_failed_cover
      @product.cover_image.purge if @product.cover_image.attached? && @product.cover_image.blob&.new_record?
    rescue StandardError
      nil
    end

    def provenance_change(field, edited, value: :unset, rows: nil)
      {
        key: field,
        source: edited ? "staff" : (@candidate.provider.presence || "isbndb"),
        provider_key: edited ? nil : (@candidate.provider_key || @candidate.isbn13),
        blank: blank_change?(field, value: value, rows: rows)
      }
    end

    def blank_change?(field, value:, rows:)
      case field
      when "contributions" then !FieldSources.contribution_present?(rows)
      when "subjects" then !FieldSources.subject_present?(rows)
      when "cover_image" then false
      when "product_form" then value.blank?
      else
        value != :unset && value.blank? && value != false && value != 0
      end
    end

    def values_equal?(left, right)
      normalize(left) == normalize(right)
    end

    def normalize(value)
      case value
      when Date then value.iso8601
      when Time, ActiveSupport::TimeWithZone then value.utc.iso8601
      when BigDecimal then value.to_s("F")
      when Integer then value
      else
        value.is_a?(String) ? value.to_s.unicode_normalize(:nfkc).strip.gsub(/\s+/, " ") : value
      end
    end

    def contribution_signature(rows)
      Array(rows).filter_map do |row|
        data = row.respond_to?(:stringify_keys) ? row.stringify_keys : { "display_name" => row.to_s, "role" => "author" }
        name = data["display_name"].to_s.unicode_normalize(:nfkc).strip.gsub(/\s+/, " ").downcase
        next if name.blank?

        [ name, Bibliographic::ContributorRole.map!(data["role"]) ]
      end
    end

    def subject_signature(rows)
      Array(rows).filter_map do |row|
        data = row.respond_to?(:stringify_keys) ? row.stringify_keys : {}
        id = data["subject_heading_id"].presence
        next if id.blank?

        [ id.to_s, ActiveModel::Type::Boolean.new.cast(data["primary"]) ]
      end.sort
    end
  end
end
