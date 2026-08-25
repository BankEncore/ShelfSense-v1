# frozen_string_literal: true

module Products
  class CreateFromCandidate
    class Error < StandardError; end

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(candidate:, actor:, attributes: {}, source: "bibliographic")
      @candidate = candidate
      @actor = actor
      @overrides = attributes.to_h.symbolize_keys
      @source = source
    end

    def call
      isbn = @overrides[:industry_identifier].presence || @candidate.isbn13.presence
      if isbn.present?
        isbn = Identifiers::Normalizer.normalize(isbn, allow_shelfsense_222: false)
        existing = Product.find_by(industry_identifier: isbn)
        raise Error, "A product already uses industry identifier #{isbn}" if existing
      elsif @candidate.isbn13.present?
        raise Error, "cached candidate includes an ISBN that was not submitted"
      end

      merged = @candidate.product_attributes.merge(
        @overrides.except(:industry_identifier, :lock_version, :cover_image_url, :binding, :cover_image, :cover_download)
      )
      assign_product_form!(merged)
      contribution_rows = submitted_contribution_rows.presence || @candidate.contribution_rows
      subject_rows = submitted_subject_rows
      subject_rows = Bibliographic::SubjectMatcher.rows_for(@candidate.subjects) if subject_rows.nil?
      sources = provenance_for(merged, contribution_rows, subject_rows, isbn)

      product = Products::Create.call(
        attributes: merged.merge(
          contribution_rows: contribution_rows,
          subject_rows: subject_rows,
          cover_image: @overrides[:cover_image],
          bibliographic_provider: @candidate.provider,
          bibliographic_provider_key: isbn.presence,
          bibliographic_fetched_at: @candidate.fetched_at,
          bibliographic_applied_at: Time.current,
          bibliographic_field_sources: sources
        ),
        actor: @actor,
        industry_identifier: isbn,
        lookup_code: @overrides[:lookup_code],
        source: @source
      )

      product
    rescue Products::Create::Error, Identifiers::NormalizationError, Bibliographic::FieldSources::Invalid,
           Bibliographic::ContributorRole::Unknown => e
      raise Error, e.message
    end

    private

    def provenance_for(merged, contribution_rows, subject_rows, isbn)
      applied_at = Time.current
      changes = []
      candidate_attrs = @candidate.product_attributes.merge(
        product_form_id: merged[:product_form_id]
      )

      Bibliographic::FieldSources::KEYS.each do |field|
        next if %w[contributions cover_image subjects binding].include?(field)

        value =
          case field
          when "industry_identifier" then isbn
          when "product_form" then merged[:product_form_id]
          else merged[field.to_sym]
          end
        next if value.blank? && value != false && value != 0

        candidate_value =
          case field
          when "industry_identifier" then @candidate.isbn13
          when "product_form" then candidate_form_id
          else candidate_attrs[field.to_sym]
          end
        edited = !values_equal?(value, candidate_value)
        changes << {
          key: field,
          source: edited ? "staff" : (@candidate.provider.presence || "isbndb"),
          provider_key: edited ? nil : (@candidate.provider_key || isbn),
          applied_at: applied_at
        }
      end

      if Bibliographic::FieldSources.contribution_present?(contribution_rows)
        edited = contribution_signature(contribution_rows) != contribution_signature(@candidate.contribution_rows)
        changes << {
          key: "contributions",
          source: edited ? "staff" : (@candidate.provider.presence || "isbndb"),
          provider_key: edited ? nil : (@candidate.provider_key || isbn),
          applied_at: applied_at
        }
      end

      if Bibliographic::FieldSources.subject_present?(subject_rows)
        edited = subject_signature(subject_rows) != subject_signature(Bibliographic::SubjectMatcher.rows_for(@candidate.subjects))
        changes << {
          key: "subjects",
          source: edited ? "staff" : (@candidate.provider.presence || "isbndb"),
          provider_key: edited ? nil : (@candidate.provider_key || isbn),
          applied_at: applied_at
        }
      end

      if @overrides[:cover_image].present?
        changes << { key: "cover_image", source: "staff", applied_at: applied_at }
      end

      Bibliographic::FieldSources.merge({}, changes, applied_at: applied_at)
    end

    def assign_product_form!(merged)
      return if merged[:product_form_id].present?

      code = @candidate.product_form_code
      return if code.blank?

      form = ProductForm.assignable.find_by(code: code)
      merged[:product_form_id] = form.id if form
    end

    def candidate_form_id
      return if @candidate.product_form_code.blank?

      ProductForm.assignable.find_by(code: @candidate.product_form_code)&.id
    end

    def values_equal?(left, right)
      normalize(left) == normalize(right)
    end

    def normalize(value)
      case value
      when Date then value.iso8601
      when Time, ActiveSupport::TimeWithZone then value.utc.iso8601
      when BigDecimal then value.to_s("F")
      else
        value.is_a?(String) ? value.to_s.unicode_normalize(:nfkc).strip.gsub(/\s+/, " ") : value
      end
    end

    def submitted_contribution_rows
      rows = Array(@overrides[:contribution_rows])
      return if rows.none? { |row|
        data = row.respond_to?(:stringify_keys) ? row.stringify_keys : {}
        data["display_name"].to_s.strip.present?
      }

      rows
    end

    def submitted_subject_rows
      return unless @overrides.key?(:subject_rows)

      @overrides[:subject_rows]
    end

    def subject_signature(rows)
      Array(rows).filter_map do |row|
        data = row.respond_to?(:stringify_keys) ? row.stringify_keys : {}
        id = data["subject_heading_id"].presence
        next if id.blank?

        [ id.to_s, ActiveModel::Type::Boolean.new.cast(data["primary"]) ]
      end.sort
    end

    def contribution_signature(rows)
      Array(rows).filter_map do |row|
        data = row.respond_to?(:stringify_keys) ? row.stringify_keys : { "display_name" => row.to_s, "role" => "author" }
        name = data["display_name"].to_s.unicode_normalize(:nfkc).strip.gsub(/\s+/, " ").downcase
        next if name.blank?

        [ name, Bibliographic::ContributorRole.map!(data["role"]) ]
      end
    end
  end
end
