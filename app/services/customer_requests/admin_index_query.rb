# frozen_string_literal: true

module CustomerRequests
  class AdminIndexQuery
    PER_PAGE = 50

    Result = Data.define(
      :records, :page, :per_page, :total_count, :total_pages,
      :q, :status, :store_id, :filtered
    )

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(scope:, q: nil, status: nil, store_id: nil, page: 1, store_filter_applied: false)
      @scope = scope
      @q = q.to_s.strip
      @status = status.to_s.presence
      @store_id = store_id.to_s.presence
      @requested_page = page
      @store_filter_applied = store_filter_applied
    end

    def call
      relation = apply_search(@scope)
      relation = relation.where(status: @status) if CustomerRequest::STATUSES.include?(@status)
      relation = relation.where(store_id: @store_id) if @store_id.present?

      total_count = relation.except(:order, :includes).distinct.count(:id)
      total_pages = [ (total_count.to_f / PER_PAGE).ceil, 1 ].max
      page = parse_page(total_pages)
      records = relation
        .order(Arel.sql(active_first_sql), created_at: :desc, id: :desc)
        .offset((page - 1) * PER_PAGE)
        .limit(PER_PAGE)

      Result.new(
        records: records,
        page: page,
        per_page: PER_PAGE,
        total_count: total_count,
        total_pages: total_pages,
        q: @q.presence,
        status: CustomerRequest::STATUSES.include?(@status) ? @status : nil,
        store_id: @store_id,
        filtered: @q.present? || @status.present? || @store_filter_applied
      )
    end

    private

    def apply_search(relation)
      return relation if @q.blank?

      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@q)}%"
      normalized_identifier = @q.gsub(/[\s-]/, "")

      relation
        .left_joins(:customer, product_variant: :product)
        .where(
          <<~SQL.squish,
            customer_requests.number::text ILIKE :pattern OR
            customers.display_name ILIKE :pattern OR
            customers.email ILIKE :pattern OR
            customers.phone ILIKE :pattern OR
            customers.id::text ILIKE :pattern OR
            products.name ILIKE :pattern OR
            products.primary_identifier = :identifier OR
            products.industry_identifier = :identifier OR
            products.lookup_code ILIKE :pattern OR
            product_variants.sku = :identifier OR
            product_variants.industry_identifier = :identifier
          SQL
          pattern: pattern,
          identifier: normalized_identifier
        )
    end

    def active_first_sql
      statuses = CustomerRequest::ACTIVE_STATUSES.map { |status| ActiveRecord::Base.connection.quote(status) }.join(", ")
      "CASE WHEN customer_requests.status IN (#{statuses}) THEN 0 ELSE 1 END"
    end

    def parse_page(total_pages)
      page = Integer(@requested_page)
      page = 1 if page < 1
      [ page, total_pages ].min
    rescue ArgumentError, TypeError
      1
    end
  end
end
