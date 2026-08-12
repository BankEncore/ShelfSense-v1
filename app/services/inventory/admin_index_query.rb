# frozen_string_literal: true

module Inventory
  class AdminIndexQuery
    PER_PAGE = 50
    Result = Struct.new(:records, :page, :total_count, :total_pages, keyword_init: true)

    DERIVED_TRACKING_SQL = <<~SQL.squish
      CASE
        WHEN merchandise_classes.inventory_mode = 'inventory'
             AND product_variants.variant_type = 'standard' THEN 'quantity'
        WHEN merchandise_classes.inventory_mode = 'inventory'
             AND product_variants.variant_type = 'used' THEN 'individual'
        WHEN merchandise_classes.inventory_mode = 'non_inventory'
             AND product_variants.variant_type = 'standard' THEN 'non_inventory'
      END
    SQL

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(store_ids:, q: nil, tracking: nil, page: 1)
      @store_ids = Array(store_ids)
      @q = q.to_s.strip
      @tracking = tracking.to_s.presence
      @page = page
    end

    def call
      scope = InventoryBalance.where(store_id: @store_ids).includes(product_variant: [ :product, :merchandise_class ])
      if @q.present? || @tracking.present?
        scope = scope.joins(product_variant: [ :product, :merchandise_class ])
      end

      if @q.present?
        normalized = @q.gsub(/[\s\-]/, "").upcase
        like = sanitize_like(normalized)
        scope = scope.where(
          "products.primary_identifier LIKE :q OR product_variants.sku LIKE :q OR product_variants.industry_identifier LIKE :q",
          q: "#{like}%"
        )
      end

      if @tracking.present?
        scope = scope.where("#{DERIVED_TRACKING_SQL} = ?", @tracking)
      end

      total = scope.unscope(:includes).count
      total_pages = [ (total.to_f / PER_PAGE).ceil, 1 ].max
      page = @page.to_i
      page = 1 if page < 1
      page = total_pages if page > total_pages
      records = scope.order(:store_id, :product_variant_id).offset((page - 1) * PER_PAGE).limit(PER_PAGE)

      Result.new(records: records, page: page, total_count: total, total_pages: total_pages)
    end

    private

    def sanitize_like(value)
      value.gsub(/[\\%_]/) { |ch| "\\#{ch}" }
    end
  end
end
