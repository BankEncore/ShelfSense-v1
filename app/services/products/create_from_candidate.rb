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
      end

      merged = @candidate.product_attributes.merge(@overrides.except(:industry_identifier, :lock_version))
      curated = Product::BIBLIOGRAPHIC_FIELD_NAMES.filter_map do |field|
        next if field == "contributions" || field == "publisher_id"
        next unless @overrides.key?(field.to_sym)
        next if @overrides[field.to_sym] == @candidate.product_attributes[field.to_sym]

        field
      end

      contribution_rows = @overrides[:contribution_rows] || @candidate.contribution_rows
      publisher_name = @overrides[:publisher_name] || @candidate.publisher_name
      curated << "publisher_id" if publisher_name != @candidate.publisher_name
      curated << "contributions" if contribution_signature(contribution_rows) != contribution_signature(@candidate.contribution_rows)

      product = Products::Create.call(
        attributes: merged.merge(
          publisher_name: publisher_name,
          contribution_rows: contribution_rows,
          bibliographic_provider: @candidate.provider,
          bibliographic_provider_key: @candidate.provider_key || isbn,
          bibliographic_fetched_at: @candidate.fetched_at,
          bibliographic_applied_at: Time.current
        ),
        actor: @actor,
        industry_identifier: isbn,
        lookup_code: @overrides[:lookup_code],
        source: @source,
        bibliographic_curated_fields: curated.uniq
      )

      product
    rescue Products::Create::Error, Identifiers::NormalizationError => e
      raise Error, e.message
    end

    private

    def contribution_signature(rows)
      Array(rows).filter_map { |row|
        data = row.respond_to?(:stringify_keys) ? row.stringify_keys : { "display_name" => row.to_s, "role" => "author" }
        name = data["display_name"].to_s.strip.downcase
        next if name.blank?

        [ name, data["role"].to_s.presence || "author" ]
      }
    end
  end
end
