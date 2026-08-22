# frozen_string_literal: true

module Pos
  class ResolveMerchandiseForSale
    OPEN_PRICE_USED_MESSAGE = "Open-price individually tracked merchandise is not supported by this POS version."

    Result = Struct.new(
      :outcome,
      :variant,
      :unit,
      :variants,
      :units,
      :product,
      :products,
      :message,
      keyword_init: true
    )

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(store:, identifier: nil, variant: nil, inventory_unit: nil, product: nil, current_transaction: nil)
      @store = store
      @identifier = identifier
      @variant = variant
      @inventory_unit = inventory_unit
      @product = product
      @current_transaction = current_transaction
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
    end

    private

    def resolve_identifier
      result = Identifiers::Lookup.call(@identifier)
      case result.status
      when :not_found, :retired
        unavailable("merchandise not found")
      when :invalid
        unavailable(result.message || "merchandise not found")
      when :inventory_unit
        resolve_unit(result.inventory_unit)
      when :variant
        resolve_variant(result.variant)
      when :product
        resolve_product(result.product)
      when :multiple_products
        Result.new(outcome: :product_choice_required, products: result.products)
      else
        unavailable("merchandise not found")
      end
    end

    # POS eligibility for a matched product identity: the matcher intentionally does
    # not filter variants, so sellability is applied here.
    def resolve_product(product)
      eligible = product.product_variants.select(&:sellable?)
      if eligible.one?
        resolve_variant(eligible.first)
      elsif eligible.many?
        Result.new(outcome: :variant_choice_required, variants: sorted_variants(eligible), product: product)
      else
        unavailable("merchandise not found")
      end
    end

    def resolve_variant(variant)
      tracking = variant.derived_inventory_tracking
      if open_price?(variant) && tracking == "individual"
        return unavailable(OPEN_PRICE_USED_MESSAGE)
      end
      unless variant.sellable?
        return unavailable(unsellable_reason(variant))
      end
      unless %w[quantity non_inventory individual].include?(tracking)
        return unavailable("merchandise tracking is not supported")
      end

      if tracking == "individual"
        units = available_units(variant)
        return Result.new(outcome: :unit_choice_required, variant: variant, units: units)
      end

      if open_price?(variant)
        return Result.new(outcome: :open_price_required, variant: variant)
      end

      if variant.regular_price_cents.nil?
        return unavailable("regular price is required")
      end

      Result.new(outcome: :addable_variant, variant: variant)
    end

    def resolve_unit(unit)
      variant = unit.product_variant
      if open_price?(variant)
        return unavailable(OPEN_PRICE_USED_MESSAGE)
      end
      unless unit.store_id == @store.id
        return unavailable("unit is not at this store")
      end
      unless unit.on_hand?
        return unavailable("unit is not on hand")
      end
      unless variant.sellable?
        return unavailable(unsellable_reason(variant))
      end
      if busy_unit_ids.include?(unit.id)
        return unavailable("unit is already on a working transaction")
      end
      if Inventory::Availability.unit_allocated?(unit)
        return unavailable("unit is reserved for a customer request")
      end

      Result.new(outcome: :addable_unit, unit: unit, variant: variant)
    end

    def available_units(variant)
      Inventory::Availability.unreserved_on_hand_units(@store, variant)
                            .where.not(id: busy_unit_ids)
                            .includes(product_variant: :merchandise_condition)
                            .order(:unit_identifier)
                            .to_a
    end

    def busy_unit_ids
      @busy_unit_ids ||= PosTransactionLine.joins(:pos_transaction)
                                           .where(pos_transactions: { status: "working" })
                                           .where.not(inventory_unit_id: nil)
                                           .pluck(:inventory_unit_id)
    end

    def open_price?(variant)
      variant.pricing_method == "open_price"
    end

    def unsellable_reason(variant)
      return "merchandise is retired" if variant.status != "active" || !variant.product.active_status?

      "merchandise is not sellable"
    end

    def sorted_variants(variants)
      variants.sort_by { |variant| [ variant.sku.to_s, variant.id.to_s ] }
    end

    def unavailable(message)
      Result.new(outcome: :unavailable, message: message)
    end
  end
end
