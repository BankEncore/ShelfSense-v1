# frozen_string_literal: true

module MerchandiseConditions
  # Refresh persisted Used variant.name projections after a condition display rename.
  class RefreshVariantNames
    def self.call(condition:)
      new(condition: condition).call
    end

    def initialize(condition:)
      @condition = condition
    end

    def call
      ProductVariant.where(variant_type: "used", merchandise_condition_id: @condition.id)
        .includes(:product, :merchandise_condition)
        .find_each do |variant|
          derived = ProductVariants::NameComposer.name_for_variant(variant)
          next if variant.name == derived

          variant.update_columns(name: derived, updated_at: Time.current)
        end
    end
  end
end
