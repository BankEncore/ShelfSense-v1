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

      variant = resolve_variant!
      validate_variant!(variant)

      PosTransaction.transaction do
        transaction = Pos::Support.lock_working_transaction!(@transaction, @expected_lock_version)
        Pos::Support.clear_working_tenders!(transaction)
        line = compatible_line(transaction, variant)
        if line
          line.quantity += @quantity
          line.recalc_extended!
          Pos::Support.apply_provisional_tax!(line)
          line.save!
        else
          line = transaction.pos_transaction_lines.build(
            line_number: next_line_number(transaction),
            direction: "sale",
            product_variant: variant,
            quantity: @quantity,
            reference_unit_price_cents: variant.regular_price_cents,
            selling_unit_price_cents: variant.regular_price_cents,
            tax_class: variant.tax_class,
            tax_class_code_snapshot: variant.tax_class.code
          )
          line.extended_selling_amount_cents = line.selling_unit_price_cents * line.quantity
          Pos::Support.apply_provisional_tax!(line)
          line.save!
        end
        Pos::Support.refresh_totals!(transaction)
        line
      end
    rescue Pos::Tax::UnresolvedApplicability => e
      raise Pos::Error, e.message
    end

    private

    def resolve_variant!
      result = Identifiers::Lookup.call(@identifier)
      raise Pos::Error, "merchandise not found" unless result.status == :variant && result.variant
      raise Pos::Error, "identifier matches multiple variants" if result.status == :multi_variant

      result.variant
    end

    def validate_variant!(variant)
      raise Pos::Error, "merchandise is not sellable" unless variant.sellable?
      raise Pos::Error, "individually tracked merchandise is not supported" unless variant.derived_inventory_tracking == "quantity"
      raise Pos::Error, "open-price merchandise is not supported" if variant.merchandise_class.pricing_method == "open_price"
      raise Pos::Error, "regular price is required" if variant.regular_price_cents.nil?
    end

    def compatible_line(transaction, variant)
      transaction.pos_transaction_lines.find do |line|
        line.product_variant_id == variant.id &&
          line.direction == "sale" &&
          line.selling_unit_price_cents == variant.regular_price_cents &&
          line.tax_class_id == variant.tax_class_id
      end
    end

    def next_line_number(transaction)
      (transaction.pos_transaction_lines.maximum(:line_number) || 0) + 1
    end
  end
end
