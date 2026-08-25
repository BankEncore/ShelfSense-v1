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
      position = 0
      @rows.each do |row|
        data = row.respond_to?(:to_unsafe_h) ? row.to_unsafe_h : row
        data = data.stringify_keys
        name = data["display_name"].to_s.unicode_normalize(:nfkc).strip.gsub(/\s+/, " ")
        next if name.blank?

        role = Bibliographic::ContributorRole.map!(data["role"])
        contribution = @product.product_contributions.find_or_initialize_by(display_name: name, role: role)
        contribution.position = position
        contribution.save!
        keep_ids << contribution.id
        position += 1
      end
      @product.product_contributions.where.not(id: keep_ids).find_each(&:destroy!)
      @product.product_contributions.reload
    end
  end
end
