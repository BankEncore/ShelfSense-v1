# frozen_string_literal: true

module Purchasing
  # Shared helpers for placing an order on the automatic open draft PO.
  module DraftPoPlacement
    module_function

    def find_or_create_open_draft!(store:, supplier:)
      raise Purchasing::Error, "store is required" if store.blank?
      raise Purchasing::Error, "supplier is required" if supplier.blank?
      raise Purchasing::Error, "supplier is inactive" unless supplier.active?

      existing = PurchaseOrder.lock.find_by(store_id: store.id, supplier_id: supplier.id, status: "draft")
      return existing if existing

      PurchaseOrder.create!(
        store: store,
        supplier: supplier,
        status: "draft",
        document_revision: 0
      )
    rescue ActiveRecord::RecordNotUnique
      PurchaseOrder.lock.find_by!(store_id: store.id, supplier_id: supplier.id, status: "draft")
    end

    def assert_standard_orderable!(product_variant)
      raise Purchasing::Error, "product variant is required" if product_variant.blank?
      raise Purchasing::Error, "Used variants cannot be ordered from suppliers" if product_variant.used?
      raise Purchasing::Error, "variant must be Standard" unless product_variant.standard?
      raise Purchasing::Error, "variant must be inventory-bearing" unless product_variant.inventory_mode == "inventory"
      raise Purchasing::Error, "variant must be active" unless product_variant.status == "active"
    end

    def economics_from(source:, expected_unit_cost_cents:)
      if source.present?
        cost = expected_unit_cost_cents.nil? ? source.derived_expected_unit_cost_cents : expected_unit_cost_cents.to_i
        raise Purchasing::Error, "expected unit cost is required" if cost.nil?

        {
          supplier_item_number_snapshot: source.supplier_item_number,
          pricing_method_snapshot: source.pricing_method,
          supplier_list_price_cents_snapshot: source.supplier_list_price_cents,
          discount_basis_points_snapshot: source.discount_basis_points,
          expected_unit_cost_cents_snapshot: cost
        }
      else
        raise Purchasing::Error, "expected unit cost is required" if expected_unit_cost_cents.nil?

        {
          supplier_item_number_snapshot: nil,
          pricing_method_snapshot: nil,
          supplier_list_price_cents_snapshot: nil,
          discount_basis_points_snapshot: nil,
          expected_unit_cost_cents_snapshot: expected_unit_cost_cents.to_i
        }
      end
    end

    def create_line!(purchase_order:, order:, economics:, notes: nil)
      raise Purchasing::Error, "purchase order must be draft" unless purchase_order.draft?
      raise Purchasing::Error, "generated purchase orders must return to draft before adding lines" if purchase_order.generated?
      raise Purchasing::Error, "order store must match purchase order store" unless order.store_id == purchase_order.store_id
      raise Purchasing::Error, "order supplier must match purchase order supplier" unless order.supplier_id == purchase_order.supplier_id

      purchase_order.lock!
      line = PurchaseOrderLine.create!(
        purchase_order: purchase_order,
        order: order,
        product_variant: order.product_variant,
        ordered_quantity: order.requested_quantity,
        notes_snapshot: notes.presence || order.notes,
        **economics
      )
      purchase_order.touch
      line
    end

    def resolve_supplier_and_source(store:, product_variant:, supplier: nil)
      source = if supplier.present?
        SupplierVariantSource.active.find_by(supplier_id: supplier.id, product_variant_id: product_variant.id)
      else
        PreferredSourceResolver.call(store: store, product_variant: product_variant)
      end

      resolved_supplier = supplier || source&.supplier
      raise Purchasing::Error, "an active supplier is required" if resolved_supplier.blank?
      raise Purchasing::Error, "supplier is inactive" unless resolved_supplier.active?

      [ resolved_supplier, source ]
    end
  end
end
