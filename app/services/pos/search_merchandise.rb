# frozen_string_literal: true

module Pos
  class SearchMerchandise
    LIMIT = 20

    Row = Struct.new(
      :variant,
      :sku,
      :product_name,
      :condition_name,
      :price_cents,
      :price_label,
      :available,
      :disabled,
      :reason,
      :tracking,
      :open_price,
      keyword_init: true
    )

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(store:, sku: nil, name: nil)
      @store = store
      @sku = sku.to_s.strip
      @name = name.to_s.strip
    end

    def call
      return [] if @sku.blank? && @name.blank?

      ranked_variants.first(LIMIT).map { |variant| build_row(variant) }
    end

    private

    def ranked_variants
      scope = ProductVariant.joins(:product).includes(
        :product,
        :merchandise_class,
        :merchandise_condition,
        :tax_class_override,
        merchandise_class: [ :department, :default_tax_class ]
      )
      conditions = []
      binds = []
      if @sku.present?
        conditions << "product_variants.sku ILIKE ?"
        binds << "#{sanitize_like(@sku)}%"
      end
      if @name.present?
        conditions << "products.name ILIKE ?"
        binds << "%#{sanitize_like(@name)}%"
      end
      scope = scope.where(conditions.join(" OR "), *binds)
      order_sql = if @sku.present?
        ActiveRecord::Base.sanitize_sql_array([
          "CASE WHEN product_variants.sku = ? THEN 0 ELSE 1 END, products.name, product_variants.sku",
          @sku
        ])
      else
        "products.name, product_variants.sku"
      end
      scope.order(Arel.sql(order_sql)).limit(LIMIT).to_a
    end

    def build_row(variant)
      tracking = variant.derived_inventory_tracking
      open_price = variant.pricing_method == "open_price"
      disabled, reason = disable_reason(variant, tracking, open_price)
      price_cents = variant.regular_price_cents
      Row.new(
        variant: variant,
        sku: variant.sku,
        product_name: variant.product.name,
        condition_name: variant.merchandise_condition&.name,
        price_cents: price_cents,
        price_label: open_price ? "Open price" : (price_cents ? format_cents(price_cents) : "—"),
        available: available_quantity(variant, tracking),
        disabled: disabled,
        reason: reason,
        tracking: tracking,
        open_price: open_price
      )
    end

    def disable_reason(variant, tracking, open_price)
      if open_price && tracking == "individual"
        return [ true, Pos::ResolveMerchandiseForSale::OPEN_PRICE_USED_MESSAGE ]
      end
      if variant.status != "active" || !variant.product.active_status?
        return [ true, "merchandise is retired" ]
      end
      return [ true, "merchandise is not sellable" ] unless variant.sellable?

      [ false, nil ]
    end

    def available_quantity(variant, tracking)
      return "—" if tracking == "non_inventory"
      return InventoryUnit.on_hand.where(store: @store, product_variant: variant).count if tracking == "individual"

      InventoryBalance.find_by(store: @store, product_variant: variant)&.on_hand_quantity || 0
    end

    def sanitize_like(value)
      value.gsub(/[%_\\]/) { |match| "\\#{match}" }
    end

    def format_cents(cents)
      sign = cents.negative? ? "-" : ""
      absolute = cents.abs
      "#{sign}$#{absolute / 100}.#{format("%02d", absolute % 100)}"
    end
  end
end
