# frozen_string_literal: true

module Inventory
  class LedgerPairIntegrity
    class Error < StandardError; end

    COMPARE_FIELDS = %w[
      store_id product_variant_id inventory_unit_id quantity_delta business_date occurred_at
      source_type source_id
    ].freeze

    def self.drifts(store_id: nil, product_variant_id: nil)
      new(store_id: store_id, product_variant_id: product_variant_id).drifts
    end

    def self.assert_pair!(ledger, valuation)
      mismatched = COMPARE_FIELDS.select { |field| ledger.public_send(field) != valuation.public_send(field) }
      return if mismatched.empty?

      raise Error, "paired rows disagree on #{mismatched.join(", ")}"
    end

    def initialize(store_id: nil, product_variant_id: nil)
      @store_id = store_id
      @product_variant_id = product_variant_id
    end

    def drifts
      reported = {}
      results = []

      scoped(InventoryLedgerEntry).find_each do |ledger|
        key = pair_key(ledger)
        valuation = InventoryValuationEntry.find_by(
          source_type: ledger.source_type,
          source_id: ledger.source_id,
          effect_sequence: ledger.effect_sequence
        )
        if valuation.nil?
          results << drift(
            ledger,
            kind: "missing_valuation",
            message: "physical entry without valuation pair"
          )
        else
          fields = mismatched_fields(ledger, valuation)
          next if fields.empty? || reported[key]

          reported[key] = true
          results << drift(
            ledger,
            kind: "pair_mismatch",
            message: "paired rows disagree on #{fields.join(", ")}"
          )
        end
      end

      scoped(InventoryValuationEntry).find_each do |valuation|
        key = pair_key(valuation)
        ledger = InventoryLedgerEntry.find_by(
          source_type: valuation.source_type,
          source_id: valuation.source_id,
          effect_sequence: valuation.effect_sequence
        )
        if ledger.nil?
          results << drift(
            valuation,
            kind: "missing_physical",
            message: "valuation entry without physical pair"
          )
        else
          fields = mismatched_fields(ledger, valuation)
          next if fields.empty? || reported[key]

          reported[key] = true
          results << drift(
            valuation,
            kind: "pair_mismatch",
            message: "paired rows disagree on #{fields.join(", ")}"
          )
        end
      end

      results
    end

    private

    def scoped(relation)
      scope = relation.all
      scope = scope.where(store_id: @store_id) if @store_id
      scope = scope.where(product_variant_id: @product_variant_id) if @product_variant_id
      scope
    end

    def pair_key(row)
      [ row.source_type, row.source_id, row.effect_sequence ]
    end

    def mismatched_fields(ledger, valuation)
      COMPARE_FIELDS.select { |field| ledger.public_send(field) != valuation.public_send(field) }
    end

    def drift(row, kind:, message:)
      Reconcile::Drift.new(
        store_id: row.store_id,
        product_variant_id: row.product_variant_id,
        kind: kind,
        expected: nil,
        actual: nil,
        message: message
      )
    end
  end
end
