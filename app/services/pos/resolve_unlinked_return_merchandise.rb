# frozen_string_literal: true

module Pos
  class ResolveUnlinkedReturnMerchandise
    SELECTION_MISMATCH_MESSAGE = "Merchandise changed. Resolve the return again."

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
      @identifier = identifier.to_s.strip.presence
      @product = product
      @variant = variant
      @inventory_unit = inventory_unit
      @lock_unit = lock_unit
      @advisory_working_unit_check = advisory_working_unit_check
    end

    def call
      if @identifier.present?
        resolve_bound_to_identifier
      elsif @inventory_unit || @variant || @product
        # Selections without an identifier are never a valid unlinked-return basis.
        raise Pos::InvalidatedDialogBasis, SELECTION_MISMATCH_MESSAGE
      else
        unavailable("merchandise not found")
      end
    rescue Identifiers::NormalizationError => e
      unavailable(e.message)
    end

    private

    def resolve_bound_to_identifier
      lookup = Identifiers::Lookup.call(@identifier)
      case lookup.status
      when :inventory_unit
        bind_direct_unit!(lookup.inventory_unit)
      when :variant
        bind_direct_variant!(lookup.variant)
      when :product
        resolve_from_product_matches([ lookup.product ])
      when :multiple_products
        resolve_from_product_matches(Array(lookup.products))
      when :retired
        unavailable("identifier is retired")
      when :not_found, :invalid
        unavailable("merchandise not found")
      else
        unavailable("merchandise not found")
      end
    end

    def bind_direct_unit!(matched_unit)
      raise Pos::InvalidatedDialogBasis, SELECTION_MISMATCH_MESSAGE if matched_unit.nil?

      if @product && @product.id != matched_unit.product_variant&.product_id
        raise Pos::InvalidatedDialogBasis, SELECTION_MISMATCH_MESSAGE
      end
      if @variant && @variant.id != matched_unit.product_variant_id
        raise Pos::InvalidatedDialogBasis, SELECTION_MISMATCH_MESSAGE
      end
      if @inventory_unit && @inventory_unit.id != matched_unit.id
        raise Pos::InvalidatedDialogBasis, SELECTION_MISMATCH_MESSAGE
      end

      resolve_unit(matched_unit)
    end

    def bind_direct_variant!(matched_variant)
      raise Pos::InvalidatedDialogBasis, SELECTION_MISMATCH_MESSAGE if matched_variant.nil?

      if @product && @product.id != matched_variant.product_id
        raise Pos::InvalidatedDialogBasis, SELECTION_MISMATCH_MESSAGE
      end
      if @variant && @variant.id != matched_variant.id
        raise Pos::InvalidatedDialogBasis, SELECTION_MISMATCH_MESSAGE
      end

      if @inventory_unit
        unless @inventory_unit.product_variant_id == matched_variant.id
          raise Pos::InvalidatedDialogBasis, SELECTION_MISMATCH_MESSAGE
        end
        return resolve_unit(@inventory_unit)
      end

      resolve_variant(matched_variant)
    end

    def resolve_from_product_matches(matched_products)
      matched_products = Array(matched_products).compact
      return unavailable("merchandise not found") if matched_products.empty?

      product = selected_product_from!(matched_products)
      return Result.new(outcome: :product_choice_required, products: sorted_products(matched_products)) if product.nil?

      candidates = product.product_variants.select { |variant| return_identity_eligible?(variant) }
      return unavailable("merchandise not found") if candidates.empty?

      if @variant
        unless candidates.any? { |candidate| candidate.id == @variant.id } && @variant.product_id == product.id
          raise Pos::InvalidatedDialogBasis, SELECTION_MISMATCH_MESSAGE
        end
        return continue_from_variant!(@variant)
      end

      if @inventory_unit
        unit_variant = @inventory_unit.product_variant
        unless unit_variant && candidates.any? { |candidate| candidate.id == unit_variant.id } &&
               unit_variant.product_id == product.id
          raise Pos::InvalidatedDialogBasis, SELECTION_MISMATCH_MESSAGE
        end
        return continue_from_variant!(unit_variant, preferred_unit: @inventory_unit)
      end

      individual, others = candidates.partition { |variant| tracking_for(variant) == "individual" }
      return unavailable("scan the unit identifier") if others.empty?

      if others.many? || individual.any?
        return Result.new(
          outcome: :variant_choice_required,
          variants: sorted_variants(candidates),
          product: product
        )
      end

      resolve_variant(others.first)
    end

    def selected_product_from!(matched_products)
      if @product
        unless matched_products.any? { |product| product.id == @product.id }
          raise Pos::InvalidatedDialogBasis, SELECTION_MISMATCH_MESSAGE
        end
        return @product
      end

      if @variant
        product = matched_products.find { |match| match.id == @variant.product_id }
        raise Pos::InvalidatedDialogBasis, SELECTION_MISMATCH_MESSAGE if product.nil?

        return product
      end

      if @inventory_unit
        product_id = @inventory_unit.product_variant&.product_id
        product = matched_products.find { |match| match.id == product_id }
        raise Pos::InvalidatedDialogBasis, SELECTION_MISMATCH_MESSAGE if product.nil?

        return product
      end

      return matched_products.first if matched_products.one?

      nil
    end

    def continue_from_variant!(variant, preferred_unit: nil)
      if preferred_unit
        unless preferred_unit.product_variant_id == variant.id
          raise Pos::InvalidatedDialogBasis, SELECTION_MISMATCH_MESSAGE
        end
        return resolve_unit(preferred_unit)
      end

      resolve_variant(variant)
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
