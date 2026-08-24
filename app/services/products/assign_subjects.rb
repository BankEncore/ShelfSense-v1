# frozen_string_literal: true

module Products
  class AssignSubjects
    class Error < StandardError; end

    def self.call(product:, rows:)
      new(product: product, rows: rows).call
    end

    def initialize(product:, rows:)
      @product = product
      @rows = Array(rows)
    end

    def call
      parsed = []
      @rows.each_with_index do |row, index|
        data = row.respond_to?(:stringify_keys) ? row.stringify_keys : row
        heading_id = data["subject_heading_id"].presence
        next if heading_id.blank?

        heading = SubjectHeading.find(heading_id)
        parsed << {
          heading: heading,
          primary: ActiveModel::Type::Boolean.new.cast(data["primary"]) == true,
          position: index
        }
      end

      existing = @product.product_subject_assignments.index_by(&:subject_heading_id)
      parsed.each do |item|
        next if existing.key?(item[:heading].id)
        next if item[:heading].assignable?

        raise Error, "must be an active heading"
      end

      @product.product_subject_assignments.update_all(primary: false)
      @product.product_subject_assignments.reset
      keep_ids = []
      parsed.each do |item|
        assignment = @product.product_subject_assignments.find_or_initialize_by(subject_heading: item[:heading])
        assignment.subject_scheme = item[:heading].subject_scheme
        assignment.position = item[:position]
        assignment.primary = item[:primary]
        assignment.save!
        keep_ids << assignment.id
      end
      @product.product_subject_assignments.where.not(id: keep_ids).find_each(&:destroy!)
      @product.product_subject_assignments.reload
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ActiveRecord::RecordNotFound => e
      raise Error, e.message
    end
  end
end
