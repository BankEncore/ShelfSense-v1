# frozen_string_literal: true

module Bibliographic
  class Candidate
    ATTRS = %i[
      candidate_id isbn13 title subtitle contributors publisher_name imprint edition binding
      language_code page_count series_name series_position release_date release_date_approximate
      description cover_image_url list_price_cents product_form_code subjects provider provider_key fetched_at
    ].freeze

    attr_accessor(*ATTRS)

    def initialize(**attrs)
      ATTRS.each { |key| public_send("#{key}=", attrs[key]) }
      self.contributors = Array(contributors)
      self.subjects = Array(subjects)
      self.provider ||= "isbndb"
      self.fetched_at ||= Time.current
      self.candidate_id ||= SecureRandom.uuid
      self.release_date_approximate = !!release_date_approximate
    end

    def to_h
      ATTRS.index_with { |key| public_send(key) }.merge(
        "contributors" => contributors.map { |row| self.class.stringify(row) },
        "subjects" => Array(subjects),
        "release_date" => release_date&.iso8601,
        "fetched_at" => fetched_at&.iso8601
      ).transform_keys(&:to_s)
    end

    def self.from_h(hash)
      data = (hash || {}).stringify_keys
      new(
        candidate_id: data["candidate_id"],
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
        release_date: parse_date(data["release_date"]),
        release_date_approximate: data["release_date_approximate"],
        description: data["description"],
        cover_image_url: data["cover_image_url"],
        list_price_cents: data["list_price_cents"],
        product_form_code: data["product_form_code"],
        subjects: Array(data["subjects"]),
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
        brand_name: publisher_name,
        imprint: imprint,
        product_model: edition,
        language_code: language_code,
        page_count: page_count,
        series_name: series_name,
        series_position: series_position,
        release_date: release_date,
        release_date_approximate: release_date_approximate,
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
