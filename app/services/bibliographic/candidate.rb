# frozen_string_literal: true

module Bibliographic
  class Candidate
    ATTRS = %i[
      isbn13 title subtitle contributors publisher_name imprint edition binding
      language_code page_count series_name series_position publication_year release_date
      description cover_image_url list_price_cents provider provider_key fetched_at
    ].freeze

    attr_accessor(*ATTRS)

    def initialize(**attrs)
      ATTRS.each { |key| public_send("#{key}=", attrs[key]) }
      self.contributors = Array(contributors)
      self.provider ||= "isbndb"
      self.fetched_at ||= Time.current
    end

    def to_h
      ATTRS.index_with { |key| public_send(key) }.merge(
        "contributors" => contributors.map { |row| self.class.stringify(row) },
        "release_date" => release_date&.iso8601,
        "fetched_at" => fetched_at&.iso8601
      ).transform_keys(&:to_s)
    end

    def self.from_h(hash)
      data = (hash || {}).stringify_keys
      new(
        isbn13: data["isbn13"],
        title: data["title"],
        subtitle: data["subtitle"],
        contributors: Array(data["contributors"]).map { |row| stringify(row) },
        publisher_name: data["publisher_name"],
        imprint: data["imprint"],
        edition: data["edition"],
        binding: data["binding"],
        language_code: data["language_code"],
        page_count: data["page_count"],
        series_name: data["series_name"],
        series_position: data["series_position"],
        publication_year: data["publication_year"],
        release_date: parse_date(data["release_date"]),
        description: data["description"],
        cover_image_url: data["cover_image_url"],
        list_price_cents: data["list_price_cents"],
        provider: data["provider"],
        provider_key: data["provider_key"],
        fetched_at: parse_time(data["fetched_at"])
      )
    end

    def product_attributes
      {
        name: title,
        subtitle: subtitle,
        description: description,
        imprint: imprint,
        edition: edition,
        binding: binding,
        language_code: language_code,
        page_count: page_count,
        series_name: series_name,
        series_position: series_position,
        publication_year: publication_year,
        release_date: release_date,
        cover_image_url: cover_image_url,
        list_price_cents: list_price_cents
      }.compact
    end

    def contribution_rows
      contributors.filter_map do |row|
        name = row.stringify_keys["display_name"].presence
        next if name.blank?

        { "display_name" => name, "role" => row.stringify_keys["role"].presence || "author" }
      end
    end

    def self.stringify(row)
      row.respond_to?(:stringify_keys) ? row.stringify_keys : { "display_name" => row.to_s, "role" => "author" }
    end

    def self.parse_date(value)
      return value if value.is_a?(Date)
      return if value.blank?

      Date.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end

    def self.parse_time(value)
      return value if value.acts_like?(:time)
      return if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError
      nil
    end
  end
end
