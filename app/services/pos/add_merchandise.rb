# frozen_string_literal: true

module Pos
  class AddMerchandise
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(transaction:, actor:, expected_lock_version:, identifier: nil, quantity: 1,
                   product_variant: nil, inventory_unit: nil, selling_price_cents: nil)
      @transaction = transaction
      @actor = actor
      @expected_lock_version = expected_lock_version
      @identifier = identifier
      @quantity = quantity.to_i
      @product_variant = product_variant
      @inventory_unit = inventory_unit
      @selling_price_cents = selling_price_cents
    end

    def call
      Pos::Support.authorize!(@actor, @transaction.store)
      Pos::Support.require_active_context!(@transaction.store, @transaction.register)
      Pos::Support.require_transaction_cashier!(@actor, @transaction)
      raise Pos::Error, "quantity must be positive" unless @quantity.positive?

      PosTransaction.transaction do
        transaction = Pos::Support.lock_working_transaction!(@transaction, @expected_lock_version)
        Pos::Support.clear_working_tenders!(transaction)
        line = add_resolved_line!(transaction)
        Pos::Support.refresh_totals!(transaction)
        Pos::Support.touch_working_transaction!(transaction)
        line
      end
    rescue Pos::Tax::UnresolvedApplicability => e
      raise Pos::Error, e.message
    end

    private

    def add_resolved_line!(transaction)
      if @inventory_unit
        add_unit_line!(transaction, @inventory_unit)
      elsif @product_variant
        add_variant_line!(transaction, @product_variant)
      else
        resolution = Pos::ResolveMerchandiseForSale.call(
          store: transaction.store,
          identifier: @identifier,
          current_transaction: transaction
        )
        case resolution.outcome
        when :addable_unit
          add_unit_line!(transaction, resolution.unit)
        when :addable_variant
          add_variant_line!(transaction, resolution.variant)
        when :open_price_required
          require_nonnegative_open_price!
          add_variant_line!(transaction, resolution.variant)
        when :variant_choice_required
          raise Pos::Error, "identifier matches multiple variants"
        when :unit_choice_required
          raise Pos::Error, "scan the unit identifier"
        else
          raise Pos::Error, resolution.message || "merchandise not found"
        end
      end
    end

    def add_unit_line!(transaction, unit)
      raise Pos::Error, "quantity must be 1 for individually tracked merchandise" unless @quantity == 1

      unit = lock_inventory_unit!(unit)
      raise Pos::Error, "unit is not at this store" unless unit.store_id == transaction.store_id
      raise Pos::Error, "unit is not on hand" unless unit.on_hand?

      variant = unit.product_variant
      raise Pos::Error, "merchandise tracking is not supported" unless variant.derived_inventory_tracking == "individual"
      if variant.merchandise_class.pricing_method == "open_price"
        raise Pos::Error, Pos::ResolveMerchandiseForSale::OPEN_PRICE_USED_MESSAGE
      end
      validate_variant!(variant, tracking: "individual")
      price_cents = unit.effective_regular_price_cents
      raise Pos::Error, "regular price is required" if price_cents.nil?
      raise Pos::Error, "unit is already on a working transaction" if working_unit_line?(unit)

      build_line!(
        transaction,
        variant: variant,
        quantity: 1,
        price_cents: price_cents,
        inventory_unit: unit,
        pricing_method_snapshot: "configured"
      )
    end

    def add_variant_line!(transaction, variant)
      tracking = variant.derived_inventory_tracking
      raise Pos::Error, "scan the unit identifier" if tracking == "individual"
      if variant.merchandise_class.pricing_method == "open_price"
        raise Pos::Error, Pos::ResolveMerchandiseForSale::OPEN_PRICE_USED_MESSAGE if tracking == "individual"
        require_nonnegative_open_price!
      end

      validate_variant!(variant, tracking: tracking)
      open_price = variant.merchandise_class.pricing_method == "open_price"
      price_cents = open_price ? @selling_price_cents : variant.regular_price_cents
      raise Pos::Error, "regular price is required" if price_cents.nil?

      unless open_price
        line = compatible_line(transaction, variant)
        if line
          line.quantity += @quantity
          line.recalc_extended!
          Pos::Support.apply_provisional_tax!(line)
          line.save!
          return line
        end
      end

      build_line!(
        transaction,
        variant: variant,
        quantity: @quantity,
        price_cents: price_cents,
        pricing_method_snapshot: open_price ? "open_price" : "configured"
      )
    end

    def lock_inventory_unit!(unit)
      InventoryUnit.lock.find(unit.id)
    rescue ActiveRecord::RecordNotFound
      raise Pos::Error, "unit is not on hand"
    end

    def validate_variant!(variant, tracking:)
      raise Pos::Error, "merchandise is not sellable" unless variant.sellable?
      unless %w[quantity non_inventory individual].include?(tracking)
        raise Pos::Error, "merchandise tracking is not supported"
      end
      if variant.merchandise_class.pricing_method == "open_price"
        raise Pos::Error, Pos::ResolveMerchandiseForSale::OPEN_PRICE_USED_MESSAGE if tracking == "individual"
        require_nonnegative_open_price!
        return
      end
      return if tracking == "individual"

      raise Pos::Error, "regular price is required" if variant.regular_price_cents.nil? && @selling_price_cents.nil?
    end

    def require_nonnegative_open_price!
      raise Pos::Error, "open price is required" if @selling_price_cents.nil?
      raise Pos::Error, "open price cannot be negative" if @selling_price_cents.negative?
    end

    def working_unit_line?(unit)
      PosTransactionLine.joins(:pos_transaction)
                        .where(inventory_unit_id: unit.id, pos_transactions: { status: "working" })
                        .exists?
    end

    def build_line!(transaction, variant:, quantity:, price_cents:, inventory_unit: nil, pricing_method_snapshot:)
      line = transaction.pos_transaction_lines.build(
        line_number: next_line_number(transaction),
        direction: "sale",
        product_variant: variant,
        inventory_unit: inventory_unit,
        quantity: quantity,
        reference_unit_price_cents: price_cents,
        selling_unit_price_cents: price_cents,
        pricing_method_snapshot: pricing_method_snapshot,
        tax_class: variant.tax_class,
        tax_class_code_snapshot: variant.tax_class.code,
        tax_class_name_snapshot: variant.tax_class.name,
        default_tax_class: variant.tax_class,
        default_tax_class_code_snapshot: variant.tax_class.code,
        default_tax_class_name_snapshot: variant.tax_class.name,
        manual_discount_cents: 0
      )
      line.extended_selling_amount_cents = line.selling_unit_price_cents * line.quantity
      line.net_merchandise_amount_cents = line.extended_selling_amount_cents
      Pos::Support.apply_provisional_tax!(line)
      line.save!
      line
    end

    def compatible_line(transaction, variant)
      transaction.pos_transaction_lines.find do |line|
        line.inventory_unit_id.nil? &&
          line.product_variant_id == variant.id &&
          line.direction == "sale" &&
          line.pricing_method_snapshot != "open_price" &&
          line.pos_controlled_actions.none? &&
          line.selling_unit_price_cents == line.reference_unit_price_cents &&
          (line.default_tax_class_id.blank? || line.tax_class_id == line.default_tax_class_id) &&
          line.selling_unit_price_cents == variant.regular_price_cents &&
          line.tax_class_id == variant.tax_class_id
      end
    end

    def next_line_number(transaction)
      (transaction.pos_transaction_lines.maximum(:line_number) || 0) + 1
    end
  end
end
