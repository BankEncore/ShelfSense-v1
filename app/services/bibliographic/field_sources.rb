# frozen_string_literal: true

module Bibliographic
  module FieldSources
    module_function

    KEYS = %w[
      name subtitle description brand_name imprint product_model
      language_code page_count series_name series_position
      release_date list_price_cents industry_identifier binding
      contributions product_form cover_image subjects
    ].freeze

    KEY_ALIASES = {
      "product_form_id" => "product_form"
    }.freeze

    COVER_EXTRA_KEYS = %w[source_url].freeze
    PROVIDERS = %w[isbndb].freeze
    ALLOWED_SOURCES = ([ "staff" ] + PROVIDERS).freeze

    class Invalid < StandardError; end

    def merge(existing, changes, applied_at: Time.current)
      document = stringify_document(existing)
      Array(changes).each do |change|
        key = change[:key].to_s
        raise Invalid, "unknown bibliographic field #{key}" unless KEYS.include?(key)

        if change[:remove] || change[:blank]
          document.delete(key)
          next
        end

        payload = entry(
          source: change[:source],
          provider_key: change[:provider_key],
          applied_at: change[:applied_at] || applied_at
        )
        cover_url = change[:source_url].presence || change[:source_url].presence
        payload["source_url"] = cover_url.to_s if key == "cover_image" && cover_url.present?
        document[key] = payload
      end
      validate!(document)
      document
    end

    def staff_for_populated(attributes, contribution_rows: nil, subject_rows: nil, cover_attached: false, applied_at: Time.current)
      changes = []
      attributes.to_h.symbolize_keys.each do |key, value|
        name = KEY_ALIASES[key.to_s] || key.to_s
        next unless KEYS.include?(name)
        next if %w[contributions subjects cover_image].include?(name)
        next if value.blank? && value != false && value != 0

        changes << { key: name, source: "staff", applied_at: applied_at }
      end
      if contribution_present?(contribution_rows)
        changes << { key: "contributions", source: "staff", applied_at: applied_at }
      end
      if subject_present?(subject_rows)
        changes << { key: "subjects", source: "staff", applied_at: applied_at }
      end
      if cover_attached
        changes << { key: "cover_image", source: "staff", applied_at: applied_at }
      end
      merge({}, changes, applied_at: applied_at)
    end

    def entry(source:, provider_key: nil, applied_at: Time.current)
      src = source.to_s
      raise Invalid, "unknown provenance source #{src}" unless ALLOWED_SOURCES.include?(src)

      payload = {
        "source" => src,
        "applied_at" => time_iso(applied_at)
      }
      if src == "staff"
        raise Invalid, "staff provenance must not include a provider key" if provider_key.present?
      else
        raise Invalid, "provider key is required for #{src}" if provider_key.blank?

        payload["provider_key"] = provider_key.to_s
      end
      payload
    end

    def validate!(document)
      hash = stringify_document(document)
      raise Invalid, "too many provenance keys" if hash.size > KEYS.size

      hash.each do |key, value|
        raise Invalid, "unknown bibliographic field #{key}" unless KEYS.include?(key)
        raise Invalid, "invalid provenance for #{key}" unless value.is_a?(Hash)

        src = value["source"].to_s
        raise Invalid, "unknown provenance source #{src}" unless ALLOWED_SOURCES.include?(src)
        raise Invalid, "applied_at is required for #{key}" if value["applied_at"].blank?
        extra = value.keys.map(&:to_s) - %w[source provider_key applied_at]
        extra -= COVER_EXTRA_KEYS if key == "cover_image"
        raise Invalid, "unsupported provenance keys for #{key}" if extra.any?
        if src == "staff"
          raise Invalid, "staff provenance must not include a provider key" if value["provider_key"].present?
        elsif value["provider_key"].blank?
          raise Invalid, "provider key is required for #{key}"
        end
      end
      hash
    end

    def stringify_document(document)
      (document.presence || {}).to_h.transform_keys(&:to_s).transform_values { |value|
        value.respond_to?(:stringify_keys) ? value.stringify_keys : value
      }
    end

    def contribution_present?(rows)
      Array(rows).any? { |row|
        data = row.respond_to?(:stringify_keys) ? row.stringify_keys : {}
        data["display_name"].to_s.gsub(/\s+/, " ").strip.present?
      }
    end

    def subject_present?(rows)
      Array(rows).any? { |row|
        data = row.respond_to?(:stringify_keys) ? row.stringify_keys : {}
        data["subject_heading_id"].present?
      }
    end

    def time_iso(value)
      time = value.respond_to?(:utc) ? value.utc : Time.iso8601(value.to_s).utc
      time.iso8601
    end
  end
end
