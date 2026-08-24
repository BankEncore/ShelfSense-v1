# frozen_string_literal: true

module Products
  class Update
    class Error < StandardError; end

    VIRTUAL_KEYS = %i[publisher_name contribution_rows].freeze

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(product:, attributes:, actor:, source: "ui", store: nil, track_curated: true)
      @product = product
      attrs = attributes.to_h.symbolize_keys
      @lock_version = attrs[:lock_version]
      @publisher_name = attrs[:publisher_name]
      @contribution_rows = attrs[:contribution_rows]
      @track_curated = track_curated
      @attributes = attrs.except(:primary_identifier, :lock_version, *VIRTUAL_KEYS)
      @actor = actor
      @source = source
      @store = store
    end

    def call
      Product.transaction do
        before = @product.attributes.slice(*audit_keys)
        @product.lock_version = @lock_version unless @lock_version.nil?

        if @attributes.key?(:industry_identifier)
          Identifiers::AssignProductIndustry.call(
            product: @product,
            raw_value: @attributes[:industry_identifier],
            actor: @actor,
            source: @source,
            persist: false
          )
        end

        resolve_publisher!
        non_id_attrs = @attributes.except(:industry_identifier)
        curated = detect_curated(non_id_attrs) if @track_curated
        @product.assign_attributes(non_id_attrs) if non_id_attrs.any?
        if @track_curated && curated.any?
          @product.bibliographic_curated_fields = (Array(@product.bibliographic_curated_fields) + curated).uniq
        end
        @product.save!
        if !@contribution_rows.nil?
          before_contributions = contribution_signature
          Products::AssignContributions.call(product: @product, rows: @contribution_rows)
          if @track_curated && contribution_signature != before_contributions
            @product.update_column(
              :bibliographic_curated_fields,
              (Array(@product.bibliographic_curated_fields) + [ "contributions" ]).uniq
            )
          end
        end

        Audit::Recorder.record!(
          action: "products.update",
          outcome: "succeeded",
          actor_user: @actor,
          actor_label: @actor.display_name,
          store: @store,
          subject: @product,
          before_values: before,
          after_values: @product.attributes.slice(*before.keys).merge(source: @source)
        )
        @product
      end
    rescue Identifiers::AssignProductIndustry::Error, ActiveRecord::RecordInvalid, ArgumentError => e
      raise Error, e.message
    end

    private

    def resolve_publisher!
      if @attributes.key?(:publisher_id)
        return
      end
      return unless @publisher_name

      if @publisher_name.to_s.strip.blank?
        @attributes[:publisher_id] = nil
      else
        @attributes[:publisher_id] = Publisher.find_or_create_normalized!(@publisher_name).id
      end
    end

    def detect_curated(attrs)
      attrs.filter_map do |key, value|
        name = key.to_s
        next unless Product::BIBLIOGRAPHIC_FIELD_NAMES.include?(name)
        next if name == "contributions"
        next unless @product.has_attribute?(name)
        next if @product.public_send(name) == value

        name
      end
    end

    def contribution_signature
      @product.product_contributions.order(:position, :id).map { |row| [ row.contributor_id, row.role ] }
    end

    def audit_keys
      %w[
        name subtitle description brand_name product_model merchandise_category_id
        list_price_cents release_date status variant_option_name_1 variant_option_name_2
        industry_identifier lookup_code publisher_id imprint edition binding language_code
        page_count series_name series_position cover_image_url publication_year
        bibliographic_provider bibliographic_provider_key
      ]
    end
  end
end
