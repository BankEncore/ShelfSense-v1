# frozen_string_literal: true

module Pos
  class ResolveUnlinkedReturnMerchandise
    Result = Struct.new(
      :variant,
      :inventory_unit,
      :tracking,
      :quantity_fixed,
      :reference_unit_price_cents,
      :tax_class,
      :description,
      keyword_init: true
    )

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(identifier:, store:, lock_unit: false, advisory_working_unit_check: true)
      @identifier = identifier
      @store = store
      @lock_unit = lock_unit
      @advisory_working_unit_check = advisory_working_unit_check
    end

    def call
      row = registry_row!
      case row.identifier_kind
      when "variant_sku", "variant_industry"
        resolve_variant!(row.product_variant)
      when "product_primary"
        resolve_product_primary!(row.product)
      when "inventory_unit"
        resolve_unit!(row.inventory_unit)
      else
        raise Pos::Error, "merchandise not found"
      end
    rescue Identifiers::NormalizationError => e
      raise Pos::Error, e.message
    end

    private

    def registry_row!
      normalized = Identifiers::Normalizer.normalize(@identifier, allow_shelfsense_222: true)
      row = Identifiers::Registry.find_any(normalized)
      raise Pos::Error, "merchandise not found" if row.nil? || row.retired_at.present?

      row
    end

    def resolve_variant!(variant)
      raise Pos::Error, "merchandise not found" if variant.nil?

      tracking = tracking_for!(variant)
      raise Pos::Error, "scan the unit identifier" if tracking == "individual"

      Result.new(**variant_result(variant, tracking: tracking))
    end

    def resolve_product_primary!(product)
      raise Pos::Error, "merchandise not found" if product.nil?

      candidates = product.product_variants.select { |variant| return_identity_eligible?(variant) }
      if candidates.empty?
        raise Pos::Error, "scan/enter variant or unit identifier"
      end

      individual, others = candidates.partition { |variant| tracking_for(variant) == "individual" }
      if others.empty?
        raise Pos::Error, "scan the unit identifier"
      end
      if others.many? || individual.any?
        raise Pos::Error, "scan/enter variant or unit identifier"
      end

      resolve_variant!(others.first)
    end

    def resolve_unit!(unit)
      raise Pos::Error, "merchandise not found" if unit.nil?

      unit = lock_unit!(unit) if @lock_unit
      variant = unit.product_variant
      raise Pos::Error, "merchandise not found" if variant.nil?
      raise Pos::Error, "scan the unit identifier" unless tracking_for!(variant) == "individual"
      raise Pos::Error, "unit is not at this store" unless unit.store_id == @store.id
      raise Pos::Error, "unit must be removed" unless unit.removed?
      raise Pos::Error, "unit is already on a working return" if working_return_unit?(unit)

      price = unit.effective_regular_price_cents
      raise Pos::Error, "regular price is required" if price.nil?

      tax_class = require_tax_class!(variant)
      Result.new(
        variant: variant,
        inventory_unit: unit,
        tracking: "individual",
        quantity_fixed: true,
        reference_unit_price_cents: price,
        tax_class: tax_class,
        description: variant.product.name
      )
    end

    def lock_unit!(unit)
      InventoryUnit.lock.find(unit.id)
    rescue ActiveRecord::RecordNotFound
      raise Pos::Error, "merchandise not found"
    end

    def working_return_unit?(unit)
      return false unless @advisory_working_unit_check || @lock_unit

      PosTransactionLine.joins(:pos_transaction)
                        .where(inventory_unit_id: unit.id, pos_transactions: { status: "working" })
                        .exists?
    end

    def variant_result(variant, tracking:)
      price = variant.regular_price_cents
      raise Pos::Error, "regular price is required" if price.nil?

      {
        variant: variant,
        inventory_unit: nil,
        tracking: tracking,
        quantity_fixed: false,
        reference_unit_price_cents: price,
        tax_class: require_tax_class!(variant),
        description: variant.product.name
      }
    end

    def return_identity_eligible?(variant)
      tracking = tracking_for(variant)
      return false unless %w[quantity non_inventory individual].include?(tracking)
      return false if variant.tax_class.nil?
      return true if tracking == "individual"

      variant.regular_price_cents.present?
    end

    def tracking_for(variant)
      variant.derived_inventory_tracking
    end

    def tracking_for!(variant)
      tracking = tracking_for(variant)
      unless %w[quantity non_inventory individual].include?(tracking)
        raise Pos::Error, "merchandise tracking is not supported"
      end

      tracking
    end

    def require_tax_class!(variant)
      tax_class = variant.tax_class
      raise Pos::Error, "Tax Class is required" if tax_class.nil?

      tax_class
    end
  end
end
