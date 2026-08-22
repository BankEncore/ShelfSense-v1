# frozen_string_literal: true

module Purchasing
  module PreferredSourceResolver
    module_function

    # Resolution order: store override → organization preferred → nil.
    def call(store:, product_variant:)
      return nil if store.blank? || product_variant.blank?

      preference = StoreSupplierSourcePreference.find_by(
        store_id: store.id,
        product_variant_id: product_variant.id
      )
      if preference&.supplier_variant_source&.active?
        return preference.supplier_variant_source
      end

      SupplierVariantSource.active.organization_preferred.find_by(
        product_variant_id: product_variant.id
      )
    end
  end
end
