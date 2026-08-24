# frozen_string_literal: true

module Products
  class AdminIndexQuery
    PER_PAGE = 50

    Result = Struct.new(
      :records, :page, :per_page, :total_count, :total_pages,
      :q, :status, :merchandise_category_id, :filtered,
      keyword_init: true
    )

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(scope: Product.all, q: nil, status: nil, merchandise_category_id: nil, page: 1)
      @scope = scope
      @q = q.to_s
      @status = status.to_s.presence
      @merchandise_category_id = merchandise_category_id.to_s.presence
      @page = page
    end

    def call
      relation = @scope
      relation = apply_search(relation)
      relation = relation.where(status: @status) if @status.present?
      if @merchandise_category_id.present?
        relation = relation.where(merchandise_category_id: @merchandise_category_id)
      end

      total_count = relation.except(:order, :select).reselect("products.id").distinct.count
      total_pages = [ (total_count.to_f / PER_PAGE).ceil, 1 ].max
      page = parse_page(total_pages)
      offset = (page - 1) * PER_PAGE

      records = relation.select("products.*").distinct.order("products.name ASC, products.id ASC").offset(offset).limit(PER_PAGE)

      Result.new(
        records: records,
        page: page,
        per_page: PER_PAGE,
        total_count: total_count,
        total_pages: total_pages,
        q: @q.presence,
        status: @status,
        merchandise_category_id: @merchandise_category_id,
        filtered: filtered?
      )
    end

    private

    def filtered?
      @q.present? || @status.present? || @merchandise_category_id.present?
    end

    def parse_page(total_pages)
      value = Integer(@page)
      return 1 if value < 1

      [ value, total_pages ].min
    rescue ArgumentError, TypeError
      1
    end

    def apply_search(relation)
      return relation if @q.blank?

      name_pattern = "%#{escape_like(@q)}%"
      identifier_digits = @q.gsub(/[\s-]/, "")
      relation = relation.left_joins(:product_contributions)

      conditions = [
        "products.name ILIKE :name ESCAPE '\\'",
        "products.subtitle ILIKE :name ESCAPE '\\'",
        "product_contributions.display_name ILIKE :name ESCAPE '\\'"
      ]
      binds = { name: name_pattern }

      if identifier_digits.match?(/\A\d+\z/)
        conditions << "products.primary_identifier = :exact OR products.primary_identifier LIKE :prefix ESCAPE '\\'"
        conditions << "products.industry_identifier = :exact OR products.industry_identifier LIKE :prefix ESCAPE '\\'"
        binds[:exact] = identifier_digits
        binds[:prefix] = "#{escape_like(identifier_digits)}%"
      end

      relation.where(conditions.join(" OR "), binds).distinct
    end

    def escape_like(value)
      value.to_s.gsub(/[\\%_]/) { |char| "\\#{char}" }
    end
  end
end
