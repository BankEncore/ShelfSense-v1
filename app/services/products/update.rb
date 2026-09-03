# frozen_string_literal: true

module Products
  class Update
    class Error < StandardError; end

    VIRTUAL_KEYS = %i[contribution_rows subject_rows cover_image cover_download].freeze
    REJECT_KEYS = %i[cover_image_url publisher_id publisher_name edition publication_year binding].freeze
    TRACKED_FIELDS = %w[
      name subtitle description brand_name imprint product_model language_code
      page_count series_name series_position release_date list_price_cents
      industry_identifier product_form_id
    ].freeze
    PROVENANCE_KEY = {
      "product_form_id" => "product_form"
    }.freeze

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(product:, attributes:, actor:, source: "ui", store: nil, provenance_changes: nil)
      @product = product
      attrs = attributes.to_h.symbolize_keys
      @lock_version = attrs[:lock_version]
      @contribution_rows = attrs[:contribution_rows]
      @subject_rows = attrs.key?(:subject_rows) ? attrs[:subject_rows] : :unset
      @cover_image = attrs[:cover_image]
      @cover_download = attrs[:cover_download]
      @provenance_changes = provenance_changes
      @attributes = attrs.except(:primary_identifier, :lock_version, *VIRTUAL_KEYS, *REJECT_KEYS)
      if @attributes.key?(:status)
        @attributes[:status] = @attributes[:status].to_s.strip.presence || "active"
      end
      @actor = actor
      @source = source
      @store = store
      @attached_blob = nil
    end

    def call
      committed = false
      product = Product.transaction do
        unless @lock_version.nil?
          expected = Integer(@lock_version)
          raise ActiveRecord::StaleObjectError.new(@product, "update") if expected != @product.lock_version
        end

        before = @product.attributes.slice(*audit_keys)
        if @attributes.key?(:release_date_approximate)
          @attributes[:release_date_approximate] = ActiveModel::Type::Boolean.new.cast(@attributes[:release_date_approximate]) == true
        end

        if @attributes.key?(:industry_identifier)
          Identifiers::AssignProductIndustry.call(
            product: @product,
            raw_value: @attributes[:industry_identifier],
            actor: @actor,
            source: @source,
            persist: false
          )
        end

        non_id_attrs = @attributes.except(:industry_identifier)
        detected = detect_staff_changes(non_id_attrs)
        @product.assign_attributes(non_id_attrs) if non_id_attrs.any?

        contribution_changed = false
        if !@contribution_rows.nil?
          before_contributions = contribution_signature
          Products::AssignContributions.call(product: @product, rows: @contribution_rows)
          contribution_changed = contribution_signature != before_contributions
        end

        subject_changed = false
        if @subject_rows != :unset
          before_subjects = subject_signature
          Products::AssignSubjects.call(product: @product, rows: @subject_rows)
          subject_changed = subject_signature != before_subjects
        end

        cover_changed = attach_cover!

        sources = apply_provenance(detected, contribution_changed, subject_changed, cover_changed)
        @product.bibliographic_field_sources = sources
        @product.save!

        Audit::Recorder.record!(
          action: "products.update",
          outcome: "succeeded",
          actor_user: @actor,
          actor_label: @actor.display_name,
          store: @store,
          subject: @product,
          before_values: before,
          after_values: @product.attributes.slice(*before.keys).merge(
            source: @source,
            applied_fields: detected + extra_applied_fields(contribution_changed, subject_changed, cover_changed)
          )
        )
        @product
      end
      committed = true
      product
    rescue Identifiers::AssignProductIndustry::Error, ActiveRecord::RecordInvalid, ArgumentError,
           Bibliographic::FieldSources::Invalid, Bibliographic::ContributorRole::Unknown,
           Products::AssignSubjects::Error, Bibliographic::CoverDownloader::Error,
           Bibliographic::CoverPayload::Error => e
      raise Error, e.message
    ensure
      @attached_blob&.purge unless committed
    end

    private

    def detect_staff_changes(attrs)
      attrs.filter_map do |key, value|
        name = key.to_s
        next unless TRACKED_FIELDS.include?(name)
        next unless @product.has_attribute?(name)
        next if values_equal?(@product.public_send(name), value)

        PROVENANCE_KEY[name] || name
      end
    end

    def extra_applied_fields(contribution_changed, subject_changed, cover_changed)
      fields = []
      fields << "contributions" if contribution_changed
      fields << "subjects" if subject_changed
      fields << "cover_image" if cover_changed
      fields
    end

    def apply_provenance(changed_fields, contribution_changed, subject_changed, cover_changed)
      changes = if @provenance_changes
        @provenance_changes
      else
        staff_changes = changed_fields.map { |field|
          attr_key = field == "product_form" ? :product_form_id : field.to_sym
          blank = field_blank?(@attributes[attr_key])
          { key: field, source: "staff", blank: blank }
        }
        if contribution_changed
          staff_changes << {
            key: "contributions",
            source: "staff",
            blank: !Bibliographic::FieldSources.contribution_present?(@contribution_rows)
          }
        end
        if subject_changed
          staff_changes << {
            key: "subjects",
            source: "staff",
            blank: !Bibliographic::FieldSources.subject_present?(@subject_rows)
          }
        end
        if cover_changed
          staff_changes << { key: "cover_image", source: "staff" }
        end
        staff_changes
      end
      Bibliographic::FieldSources.merge(@product.bibliographic_field_sources, changes)
    end

    def attach_cover!
      if @cover_download
        attach_blob!(@cover_download.bytes, @cover_download.filename, @cover_download.content_type)
        true
      elsif @cover_image.present?
        payload = Bibliographic::CoverPayload.from_upload(@cover_image)
        attach_blob!(payload.bytes, payload.filename, payload.content_type)
        true
      else
        false
      end
    end

    def attach_blob!(bytes, filename, content_type)
      @attached_blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(bytes),
        filename: filename,
        content_type: content_type
      )
      @product.cover_image.attach(@attached_blob)
    end

    def field_blank?(value)
      value.blank? && value != false && value != 0
    end

    def values_equal?(left, right)
      normalize_compare(left) == normalize_compare(right)
    end

    def normalize_compare(value)
      case value
      when Date then value.iso8601
      when Time, ActiveSupport::TimeWithZone then value.utc.iso8601
      when BigDecimal then value.to_s("F")
      else
        value.is_a?(String) ? value.to_s.unicode_normalize(:nfkc).strip.gsub(/\s+/, " ") : value
      end
    end

    def contribution_signature
      @product.product_contributions.order(:position, :id).map { |row| [ row.display_name, row.role, row.position ] }
    end

    def subject_signature
      @product.product_subject_assignments.order(:position, :id).map { |row|
        [ row.subject_heading_id, row.primary, row.position ]
      }
    end

    def audit_keys
      %w[
        name subtitle description brand_name product_model merchandise_category_id product_form_id
        list_price_cents release_date release_date_approximate status variant_option_name_1
        variant_option_name_2 industry_identifier lookup_code imprint language_code
        page_count series_name series_position bibliographic_provider bibliographic_provider_key
      ]
    end
  end
end
