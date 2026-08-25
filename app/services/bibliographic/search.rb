# frozen_string_literal: true

module Bibliographic
  class Search
    class Error < StandardError; end

    Result = Struct.new(
      :status, :existing_product, :local_suggestions, :strong_matches, :weak_matches,
      :candidates, :message,
      keyword_init: true
    )

    class_attribute :provider_factory, default: -> { Bibliographic::Providers::IsbnDb.new }

    def self.call(query:, skip_local: false)
      new(query: query, skip_local: skip_local).call
    end

    def initialize(query:, provider: nil, skip_local: false)
      @raw = query.to_s.strip
      @provider = provider || self.class.provider_factory.call
      @skip_local = skip_local
    end

    def call
      return Result.new(status: :invalid, message: "Enter an ISBN or title") if @raw.blank?

      unless @skip_local
        local = local_identity
        return local if local
      end

      isbn = try_isbn
      if isbn
        candidates = cached_or_fetch("isbn:#{isbn}", Bibliographic::LookupCache::ISBN_TTL) {
          @provider.find_by_isbn(isbn)
        }
        return Result.new(status: :candidates, candidates: candidates, **match_groups(candidates)) if candidates.any?

        return Result.new(status: :not_found, message: "No bibliographic match for that ISBN")
      end

      candidates = cached_or_fetch("title:#{Bibliographic::NameNormalizer.call(@raw)}", Bibliographic::LookupCache::TITLE_TTL) {
        @provider.search_title(@raw)
      }
      Result.new(status: :candidates, candidates: candidates, **match_groups(candidates, fallback_title: @raw))
    rescue Bibliographic::HttpClient::Unavailable, Bibliographic::HttpClient::TimeoutError => e
      Result.new(status: :unavailable, message: e.message, **match_groups([], fallback_title: @raw))
    end

    private

    def local_identity
      result = Identifiers::Lookup.call(@raw)
      case result.status
      when :product
        Result.new(status: :existing, existing_product: result.product)
      when :variant
        Result.new(status: :existing, existing_product: result.variant.product)
      when :inventory_unit
        Result.new(status: :existing, existing_product: result.product)
      when :multiple_products
        Result.new(status: :local_choices, local_suggestions: result.products)
      end
    rescue Identifiers::NormalizationError
      nil
    end

    def try_isbn
      Identifiers::Normalizer.normalize(@raw, allow_shelfsense_222: false)
    rescue Identifiers::NormalizationError
      nil
    end

    def match_groups(candidates, fallback_title: nil)
      first = Array(candidates).first
      matches = Bibliographic::PossibleMatches.call(
        candidate: first,
        title: first&.title,
        subtitle: first&.subtitle,
        contributors: first&.contributors,
        isbn13: first&.isbn13
      )
      extra = fallback_title.present? ? Bibliographic::PossibleMatches.call(title: fallback_title) : nil
      strong = (matches.strong + Array(extra&.strong)).uniq(&:id)
      weak = ((matches.weak + Array(extra&.weak)).uniq(&:id) - strong)
      {
        local_suggestions: strong + weak,
        strong_matches: strong,
        weak_matches: weak
      }
    end

    def cached_or_fetch(key, ttl)
      cached = Bibliographic::LookupCache.fetch(key)
      return cached if cached

      candidates = yield
      Bibliographic::LookupCache.store(key, candidates, ttl: ttl)
      Array(candidates).each do |candidate|
        next if candidate.isbn13.blank?

        Bibliographic::LookupCache.store(
          "isbn:#{candidate.isbn13}",
          [ candidate ],
          ttl: Bibliographic::LookupCache::ISBN_TTL
        )
      end
      candidates
    end
  end
end
