# frozen_string_literal: true

module Products
  class AssignContributions
    def self.call(product:, rows:)
      new(product: product, rows: rows).call
    end

    def initialize(product:, rows:)
      @product = product
      @rows = Array(rows)
    end

    def call
      keep_ids = []
      @rows.each_with_index do |row, index|
        data = row.respond_to?(:to_unsafe_h) ? row.to_unsafe_h : row
        data = data.stringify_keys
        next if data["display_name"].to_s.strip.blank?

        contributor = Contributor.find_or_create_normalized!(data["display_name"])
        role = data["role"].presence_in(ProductContribution::ROLES) || "author"
        contribution = @product.product_contributions.find_or_initialize_by(contributor: contributor, role: role)
        contribution.position = index
        contribution.save!
        keep_ids << contribution.id
      end
      @product.product_contributions.where.not(id: keep_ids).find_each(&:destroy!)
      @product.product_contributions.reload
    end
  end
end
