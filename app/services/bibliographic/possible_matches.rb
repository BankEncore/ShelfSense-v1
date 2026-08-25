# frozen_string_literal: true

module Bibliographic
  class PossibleMatches
    Result = Struct.new(:exact_products, :strong, :weak, keyword_init: true)

    def self.call(candidate: nil, title: nil, subtitle: nil, contributors: [], isbn13: nil)
      new(
        candidate: candidate,
        title: title,
        subtitle: subtitle,
        contributors: contributors,
        isbn13: isbn13
      ).call
    end

    def initialize(candidate: nil, title: nil, subtitle: nil, contributors: [], isbn13: nil)
      @candidate = candidate
      @title = (title.presence || candidate&.title).to_s
      @subtitle = (subtitle.presence || candidate&.subtitle).to_s
      @contributors = Array(contributors.presence || candidate&.contributors)
      @isbn13 = isbn13.presence || candidate&.isbn13
    end

    def call
      exact = exact_products
      remaining = Product.where.not(id: exact.map(&:id))
      strong = strong_matches(remaining)
      weak = weak_matches(remaining.where.not(id: strong.map(&:id)))
      Result.new(exact_products: exact, strong: strong, weak: weak)
    end

    private

    def exact_products
      return [] if @isbn13.blank?

      begin
        value = Identifiers::Normalizer.normalize(@isbn13, allow_shelfsense_222: false)
      rescue Identifiers::NormalizationError
        return []
      end
      Product.where(industry_identifier: value).to_a
    end

    def strong_matches(scope)
      title_key = Bibliographic::NameNormalizer.call(@title)
      return [] if title_key.blank?

      contributor_names = @contributors.filter_map { |row|
        Bibliographic::NameNormalizer.call(row.stringify_keys["display_name"])
      }.uniq
      subtitle_key = Bibliographic::NameNormalizer.call(@subtitle)

      scope.includes(:product_contributions).select { |product|
        product_title = Bibliographic::NameNormalizer.call(product.name)
        next false unless product_title == title_key

        product_subtitle = Bibliographic::NameNormalizer.call(product.subtitle)
        subtitle_hit = subtitle_key.present? && product_subtitle == subtitle_key
        contributor_hit = contributor_names.any? && product.product_contributions.any? { |row|
          contributor_names.include?(Bibliographic::NameNormalizer.call(row.display_name))
        }
        contributor_hit || subtitle_hit
      }.first(10)
    end

    def weak_matches(scope)
      return [] if @title.blank?

      pattern = "%#{escape_like(@title.downcase)}%"
      relation = scope.where("LOWER(products.name) LIKE ? ESCAPE '\\' OR LOWER(COALESCE(products.subtitle, '')) LIKE ? ESCAPE '\\'", pattern, pattern)
      if @subtitle.present?
        sub_pattern = "%#{escape_like(@subtitle.downcase)}%"
        relation = relation.or(
          scope.where("LOWER(COALESCE(products.subtitle, '')) LIKE ? ESCAPE '\\'", sub_pattern)
        )
      end
      relation.order(:name, :id).limit(10).to_a
    end

    def escape_like(value)
      value.to_s.gsub(/[\\%_]/) { |char| "\\#{char}" }
    end
  end
end
