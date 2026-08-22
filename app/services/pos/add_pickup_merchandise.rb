# frozen_string_literal: true

module Pos
  class AddPickupMerchandise
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(transaction:, actor:, expected_lock_version:, customer_request: nil, allocation: nil)
      @transaction = transaction
      @actor = actor
      @expected_lock_version = expected_lock_version
      @customer_request = customer_request
      @allocation = allocation
    end

    def call
      Pos::Support.authorize!(@actor, @transaction.store)
      authorize_pickup!
      Pos::Support.require_active_context!(@transaction.store, @transaction.register)
      Pos::Support.require_transaction_cashier!(@actor, @transaction)

      PosTransaction.transaction do
        transaction = Pos::Support.lock_working_transaction!(@transaction, @expected_lock_version)
        Pos::Support.clear_working_tenders!(transaction)

        allocation = resolve_allocation!
        raise Pos::Error, "allocation is already on a working transaction" if working_allocation_line?(allocation)

        variant = allocation.customer_request.product_variant
        raise Pos::Error, "merchandise is not sellable" unless variant.sellable?

        line =
          if allocation.used_unit?
            add_used_pickup!(transaction, allocation, variant)
          else
            add_standard_pickup!(transaction, allocation, variant)
          end

        Pos::Support.refresh_totals!(transaction)
        Pos::Support.touch_working_transaction!(transaction)
        line
      end
    rescue Pos::Tax::UnresolvedApplicability => e
      raise Pos::Error, e.message
    end

    private

    def authorize_pickup!
      unless Authorization::PermissionEvaluator.allowed?(
        user: @actor,
        permission_key: "customer_requests.pickup",
        store: @transaction.store
      )
        raise Pos::Denied, "not authorized to pick up customer requests at this store"
      end
    end

    def resolve_allocation!
      allocation =
        if @allocation
          CustomerRequestAllocation.find(@allocation.id)
        elsif @customer_request
          request = CustomerRequest.find(@customer_request.id)
          raise Pos::Error, "customer request is not available for pickup" unless request.available?
          raise Pos::Error, "customer request is not at this store" unless request.store_id == @transaction.store_id

          request.active_allocation
        end

      raise Pos::Error, "customer request allocation is required" if allocation.blank?
      raise Pos::Error, "allocation is not reserved" unless allocation.reserved?

      request = allocation.customer_request
      raise Pos::Error, "customer request is not available for pickup" unless request.available?
      raise Pos::Error, "customer request is not at this store" unless request.store_id == @transaction.store_id

      allocation
    rescue ActiveRecord::RecordNotFound
      raise Pos::Error, "customer request allocation not found"
    end

    def working_allocation_line?(allocation)
      PosTransactionLine.joins(:pos_transaction)
                        .where(
                          customer_request_allocation_id: allocation.id,
                          pos_transactions: { status: "working" }
                        )
                        .exists?
    end

    def add_standard_pickup!(transaction, allocation, variant)
      raise Pos::Error, "scan the unit identifier" if variant.derived_inventory_tracking == "individual"
      raise Pos::Error, "regular price is required" if variant.regular_price_cents.nil?

      build_line!(
        transaction,
        variant: variant,
        quantity: 1,
        price_cents: variant.regular_price_cents,
        allocation: allocation,
        inventory_unit: nil
      )
    end

    def add_used_pickup!(transaction, allocation, variant)
      unit = InventoryUnit.lock.find(allocation.inventory_unit_id)
      raise Pos::Error, "unit is not at this store" unless unit.store_id == transaction.store_id
      raise Pos::Error, "unit is not on hand" unless unit.on_hand?
      raise Pos::Error, "unit is already on a working transaction" if working_unit_line?(unit)
      if variant.pricing_method == "open_price"
        raise Pos::Error, Pos::ResolveMerchandiseForSale::OPEN_PRICE_USED_MESSAGE
      end

      price_cents = unit.effective_regular_price_cents
      raise Pos::Error, "regular price is required" if price_cents.nil?

      build_line!(
        transaction,
        variant: variant,
        quantity: 1,
        price_cents: price_cents,
        allocation: allocation,
        inventory_unit: unit
      )
    rescue ActiveRecord::RecordNotFound
      raise Pos::Error, "unit is not on hand"
    end

    def working_unit_line?(unit)
      PosTransactionLine.joins(:pos_transaction)
                        .where(inventory_unit_id: unit.id, pos_transactions: { status: "working" })
                        .exists?
    end

    def build_line!(transaction, variant:, quantity:, price_cents:, allocation:, inventory_unit:)
      tax = variant.effective_tax_class
      raise Pos::Error, "effective tax class is required" if tax.blank?

      line = transaction.pos_transaction_lines.build(
        line_number: next_line_number(transaction),
        direction: "sale",
        product_variant: variant,
        inventory_unit: inventory_unit,
        customer_request_allocation: allocation,
        quantity: quantity,
        reference_unit_price_cents: price_cents,
        selling_unit_price_cents: price_cents,
        pricing_method_snapshot: "configured",
        tax_class: tax,
        tax_class_code_snapshot: tax.code,
        tax_class_name_snapshot: tax.name,
        default_tax_class: tax,
        default_tax_class_code_snapshot: tax.code,
        default_tax_class_name_snapshot: tax.name,
        manual_discount_cents: 0
      )
      line.extended_selling_amount_cents = line.selling_unit_price_cents * line.quantity
      line.net_merchandise_amount_cents = line.extended_selling_amount_cents
      Pos::Support.apply_provisional_tax!(line)
      line.save!
      line
    end

    def next_line_number(transaction)
      (transaction.pos_transaction_lines.maximum(:line_number) || 0) + 1
    end
  end
end
