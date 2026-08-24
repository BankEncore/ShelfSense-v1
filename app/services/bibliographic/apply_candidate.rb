# frozen_string_literal: true

module Bibliographic
  class ApplyCandidate
    class Error < StandardError; end

    def self.call(**attrs)
      new(**attrs).call
    end

    attr_reader :applied_fields

    def initialize(product:, candidate:, actor:, overwrite_curated: false, source: "bibliographic")
      @product = product
      @candidate = candidate
      @actor = actor
      @overwrite_curated = overwrite_curated
      @source = source
      @applied_fields = []
    end

    def call
      attrs = {}
      @candidate.product_attributes.each do |field, value|
        next if value.blank? && value != false
        next unless apply_field?(field.to_s)

        attrs[field] = value
        @applied_fields << field.to_s
      end

      if @candidate.publisher_name.present? && apply_field?("publisher_id")
        attrs[:publisher_id] = Publisher.find_or_create_normalized!(@candidate.publisher_name).id
        @applied_fields << "publisher_id"
      end

      Products::Update.call(
        product: @product,
        attributes: attrs.merge(
          bibliographic_provider: @candidate.provider,
          bibliographic_provider_key: @candidate.provider_key || @candidate.isbn13,
          bibliographic_fetched_at: @candidate.fetched_at,
          bibliographic_applied_at: Time.current,
          lock_version: @product.lock_version
        ),
        actor: @actor,
        source: @source,
        track_curated: false
      )

      if apply_field?("contributions") && @candidate.contribution_rows.any?
        Products::AssignContributions.call(product: @product.reload, rows: @candidate.contribution_rows)
        @applied_fields << "contributions"
      end

      @product.reload
    rescue Products::Update::Error, ArgumentError => e
      raise Error, e.message
    end

    private

    def apply_field?(name)
      return true if @overwrite_curated

      !Array(@product.bibliographic_curated_fields).include?(name)
    end
  end
end
