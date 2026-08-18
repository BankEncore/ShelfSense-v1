# frozen_string_literal: true

module Pos
  class AddMerchandise
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(transaction:, actor:, expected_lock_version:, identifier:, quantity: 1)
      @transaction = transaction
      @actor = actor
      @expected_lock_version = expected_lock_version
      @identifier = identifier
      @quantity = quantity.to_i
    end

    def call
      Pos::Support.authorize!(@actor, @transaction.store)
      Pos::Support.require_active_context!(@transaction.store, @transaction.register)
      Pos::Support.require_transaction_cashier!(@actor, @transaction)
      raise Pos::Error, "quantity must be positive" unless @quantity.positive?

      result = Identifiers::Lookup.call(@identifier)
      raise Pos::Error, "merchandise not found" if result.status == :not_found || result.status == :retired
      raise Pos::Error, "identifier matches multiple variants" if result.status == :multi_variant
      raise Pos::Error, result.message || "merchandise not found" if result.status == :invalid
      raise Pos::Error, "merchandise not found" unless result.status == :variant || result.status == :inventory_unit

      PosTransaction.transaction do
        transaction = Pos::Support.lock_working_transaction!(@transaction, @expected_lock_version)
        Pos::Support.clear_working_tenders!(transaction)
        line = if result.status == :inventory_unit
          add_unit_line!(transaction, result.inventory_unit)
        else
          add_variant_line!(transaction, result.variant)
        end
        Pos::Support.refresh_totals!(transaction)
        line
      end
    rescue Pos::Tax::UnresolvedApplicability => e
      raise Pos::Error, e.message
    end

    private

    def add_unit_line!(transaction, unit)
      raise Pos::Error, "quantity must be 1 for individually tracked merchandise" unless @quantity == 1

      unit = lock_inventory_unit!(unit)
      raise Pos::Error, "unit is not at this store" unless unit.store_id == transaction.store_id
      raise Pos::Error, "unit is not on hand" unless unit.on_hand?

      variant = unit.product_variant
      raise Pos::Error, "merchandise tracking is not supported" unless variant.derived_inventory_tracking == "individual"
      validate_variant!(variant, tracking: "individual")
      price_cents = unit.effective_regular_price_cents
      raise Pos::Error, "regular price is required" if price_cents.nil?
      raise Pos::Error, "unit is already on a working transaction" if working_unit_line?(unit)

      build_line!(
        transaction,
        variant: variant,
        quantity: 1,
        price_cents: price_cents,
        inventory_unit: unit
      )
    end

    def add_variant_line!(transaction, variant)
      tracking = variant.derived_inventory_tracking
      raise Pos::Error, "scan the unit identifier" if tracking == "individual"

      validate_variant!(variant, tracking: tracking)
      line = compatible_line(transaction, variant)
      if line
        line.quantity += @quantity
        line.recalc_extended!
        Pos::Support.apply_provisional_tax!(line)
        line.save!
        return line
      end

      build_line!(
        transaction,
        variant: variant,
        quantity: @quantity,
        price_cents: variant.regular_price_cents
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
      raise Pos::Error, "open-price merchandise is not supported" if variant.merchandise_class.pricing_method == "open_price"
      return if tracking == "individual"

      raise Pos::Error, "regular price is required" if variant.regular_price_cents.nil?
    end

    def working_unit_line?(unit)
      PosTransactionLine.joins(:pos_transaction)
                        .where(inventory_unit_id: unit.id, pos_transactions: { status: "working" })
                        .exists?
    end

    def build_line!(transaction, variant:, quantity:, price_cents:, inventory_unit: nil)
      line = transaction.pos_transaction_lines.build(
        line_number: next_line_number(transaction),
        direction: "sale",
        product_variant: variant,
        inventory_unit: inventory_unit,
        quantity: quantity,
        reference_unit_price_cents: price_cents,
        selling_unit_price_cents: price_cents,
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
