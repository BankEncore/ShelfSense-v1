# frozen_string_literal: true

module Pos
  class ResolveUnlinkedReturnMerchandise
    Result = Struct.new(
      :outcome,
      :variant,
      :inventory_unit,
      :tracking,
      :quantity_fixed,
      :reference_unit_price_cents,
      :tax_class,
      :description,
      :product,
      :products,
      :variants,
      :units,
      :message,
      keyword_init: true
    )

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      store:,
      identifier: nil,
      product: nil,
      variant: nil,
      inventory_unit: nil,
      lock_unit: false,
      advisory_working_unit_check: true
    )
      @store = store
      @identifier = identifier
      @product = product
      @variant = variant
      @inventory_unit = inventory_unit
      @lock_unit = lock_unit
      @advisory_working_unit_check = advisory_working_unit_check
    end

    def call
      if @inventory_unit
        resolve_unit(@inventory_unit)
      elsif @variant
        resolve_variant(@variant)
      elsif @product
        resolve_product(@product)
      else
        resolve_identifier
      end
    rescue Identifiers::NormalizationError => e
      unavailable(e.message)
    end

    private

    def resolve_identifier
      result = Identifiers::Lookup.call(@identifier)
      case result.status
      when :variant
        resolve_variant(result.variant)
      when :product
        resolve_product(result.product)
      when :multiple_products
        Result.new(
          outcome: :product_choice_required,
          products: sorted_products(result.products)
        )
      when :inventory_unit
        resolve_unit(result.inventory_unit)
      when :retired
        unavailable("identifier is retired")
      else
        unavailable("merchandise not found")
      end
    end

    def resolve_product(product)
      return unavailable("merchandise not found") if product.nil?

      candidates = product.product_variants.select { |variant| return_identity_eligible?(variant) }
      return unavailable("merchandise not found") if candidates.empty?

      individual, others = candidates.partition { |variant| tracking_for(variant) == "individual" }

      if others.empty?
        return unavailable("scan the unit identifier")
      end

      if others.many? || individual.any?
        return Result.new(
          outcome: :variant_choice_required,
          variants: sorted_variants(candidates),
          product: product
        )
      end

      resolve_variant(others.first)
    end

    def resolve_variant(variant)
      return unavailable("merchandise not found") if variant.nil?

      tracking = tracking_for!(variant)
      return unavailable("merchandise tracking is not supported") if tracking.nil?
      return unavailable("Tax Class is required") if require_tax_class!(variant).nil?

      if tracking == "individual"
        units = available_return_units(variant)
        return Result.new(outcome: :unit_choice_required, variant: variant, units: units)
      end

      resolved(variant, tracking: tracking)
    end

    def resolve_unit(unit)
      return unavailable("merchandise not found") if unit.nil?

      if @lock_unit
        unit = lock_unit!(unit)
        return unavailable("merchandise not found") if unit.nil?
      end
      variant = unit.product_variant
      return unavailable("merchandise not found") if variant.nil?
      return unavailable("scan the unit identifier") if tracking_for!(variant) != "individual"
      return unavailable("unit is not at this store") unless unit.store_id == @store.id
      return unavailable("unit must be removed") unless unit.removed?
      return unavailable("unit is already on a working return") if working_return_unit?(unit)

      price = unit.effective_regular_price_cents
      return unavailable("regular price is required") if price.nil?

      tax_class = require_tax_class!(variant)
      return unavailable("Tax Class is required") if tax_class.nil?

      Result.new(
        outcome: :resolved,
        variant: variant,
        inventory_unit: unit,
        tracking: "individual",
        quantity_fixed: true,
        reference_unit_price_cents: price,
        tax_class: tax_class,
        description: variant.product.name
      )
    end

    def resolved(variant, tracking:)
      price = variant.regular_price_cents
      return unavailable("regular price is required") if price.nil?

      tax_class = require_tax_class!(variant)
      return unavailable("Tax Class is required") if tax_class.nil?

      Result.new(
        outcome: :resolved,
        variant: variant,
        inventory_unit: nil,
        tracking: tracking,
        quantity_fixed: false,
        reference_unit_price_cents: price,
        tax_class: tax_class,
        description: variant.product.name
      )
    end

    def available_return_units(variant)
      InventoryUnit.where(lifecycle_state: "removed", store: @store, product_variant: variant)
                   .where.not(id: busy_return_unit_ids)
                   .includes(product_variant: :merchandise_condition)
                   .order(:unit_identifier)
                   .to_a
    end

    def busy_return_unit_ids
      @busy_return_unit_ids ||= PosTransactionLine.joins(:pos_transaction)
                                                  .where(pos_transactions: { status: "working" })
                                                  .where.not(inventory_unit_id: nil)
                                                  .pluck(:inventory_unit_id)
    end

    def lock_unit!(unit)
      InventoryUnit.lock.find(unit.id)
    rescue ActiveRecord::RecordNotFound
      nil
    end

    def working_return_unit?(unit)
      return false unless @advisory_working_unit_check || @lock_unit

      busy_return_unit_ids.include?(unit.id)
    end

    def return_identity_eligible?(variant)
      tracking = tracking_for(variant)
      return false unless %w[quantity non_inventory individual].include?(tracking)
      return false if variant.effective_tax_class.nil?

      true
    end

    def tracking_for(variant)
      variant.derived_inventory_tracking
    end

    def tracking_for!(variant)
      tracking = tracking_for(variant)
      return nil unless %w[quantity non_inventory individual].include?(tracking)

      tracking
    end

    def require_tax_class!(variant)
      variant.effective_tax_class
    end

    def sorted_variants(variants)
      variants.sort_by { |variant| [ variant.sku.to_s, variant.id.to_s ] }
    end

    def sorted_products(products)
      products.sort_by { |product| [ product.name.to_s.downcase, product.primary_identifier.to_s ] }
    end

    def unavailable(message)
      Result.new(outcome: :unavailable, message: message)
    end
  end
end
