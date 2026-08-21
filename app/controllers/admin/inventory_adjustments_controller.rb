# frozen_string_literal: true

module Admin
  class InventoryAdjustmentsController < BaseController
    before_action -> { require_permission!("inventory.view") }, only: :show
    before_action -> { require_permission!("inventory.adjust") }, only: %i[new create preview]
    before_action -> { require_permission!("inventory.reverse_adjustment") }, only: %i[reverse confirm_reverse]
    before_action :set_adjustment, only: %i[show reverse confirm_reverse]

    def show
      return unless authorize!("inventory.view", store: @adjustment.store)

      @ledger = InventoryLedgerEntry.find_by(source_type: "InventoryAdjustment", source_id: @adjustment.id)
      @valuation = InventoryValuationEntry.find_by(source_type: "InventoryAdjustment", source_id: @adjustment.id)
    end

    def new
      @store = resolve_store
      return unless @store.nil? || authorize!("inventory.adjust", store: @store)

      @product_variant = resolve_product_variant(params[:product_variant_id]) if params[:product_variant_id].present?
      @reasons = AdjustmentReason.active.where.not(code: "reversal").order(:code)
      @command_token = SecureRandom.uuid_v7
      @idempotency_key = SecureRandom.uuid_v7
      @on_hand_units =
        if @product_variant&.derived_inventory_tracking == "individual" && @store
          InventoryUnit.on_hand.where(store: @store, product_variant: @product_variant).order(:unit_identifier)
        end
    end

    def preview
      @store = Store.find(params.require(:store_id))
      return unless authorize!("inventory.adjust", store: @store)

      @product_variant = resolve_product_variant!(params.require(:product_variant_id))
      reason = AdjustmentReason.find(params.require(:adjustment_reason_id))
      cost = parse_money(params[:acquisition_unit_cost])
      @preview = Inventory::PostAdjustment.preview(
        store: @store,
        product_variant: @product_variant,
        adjustment_reason: reason,
        quantity_delta: params.require(:quantity_delta),
        actor: current_user,
        source_id: params.require(:command_token),
        idempotency_key: params.require(:idempotency_key),
        acquisition_unit_cost_cents: cost,
        unit_identifier: params[:unit_identifier].presence,
        notes: params[:notes],
        allow_backdate: effective_permissions.include?("inventory.backdate"),
        occurred_at: occurred_at_param,
        regular_price_cents: parse_money(params[:regular_price])
      )
      @command_token = params[:command_token]
      @idempotency_key = params[:idempotency_key]
      @form = params.permit(
        :store_id, :product_variant_id, :adjustment_reason_id, :quantity_delta, :acquisition_unit_cost,
        :notes, :occurred_at, :regular_price, :unit_identifier, :command_token, :idempotency_key
      )
      render :confirm
    rescue Inventory::PostAdjustment::Error, Money::ParseCents::Error, ArgumentError => e
      redirect_to new_admin_inventory_adjustment_path(product_variant_id: params[:product_variant_id], store_id: params[:store_id]),
                  alert: e.message
    end

    def create
      store = Store.find(params.require(:store_id))
      return unless authorize!("inventory.adjust", store: store)

      variant = resolve_product_variant!(params.require(:product_variant_id))
      reason = AdjustmentReason.find(params.require(:adjustment_reason_id))
      cost = parse_money(params[:acquisition_unit_cost])
      adjustment = Inventory::PostAdjustment.call(
        store: store,
        product_variant: variant,
        adjustment_reason: reason,
        quantity_delta: params.require(:quantity_delta),
        actor: current_user,
        source_id: params.require(:command_token),
        idempotency_key: params.require(:idempotency_key),
        acquisition_unit_cost_cents: cost,
        unit_identifier: params[:unit_identifier].presence,
        regular_price_cents: parse_money(params[:regular_price]),
        notes: params[:notes],
        allow_backdate: effective_permissions.include?("inventory.backdate"),
        occurred_at: occurred_at_param,
        negative_stock_policy: "reject_below_zero"
      )
      redirect_to admin_inventory_adjustment_path(adjustment), notice: "Adjustment posted."
    rescue Inventory::PostAdjustment::Error, Money::ParseCents::Error, Idempotency::OperationService::PayloadMismatchError, ArgumentError => e
      redirect_to new_admin_inventory_adjustment_path(product_variant_id: params[:product_variant_id], store_id: params[:store_id]),
                  alert: e.message
    end

    def reverse
      return unless authorize!("inventory.reverse_adjustment", store: @adjustment.store)

      @command_token = SecureRandom.uuid_v7
      @idempotency_key = SecureRandom.uuid_v7
    end

    def confirm_reverse
      return unless authorize!("inventory.reverse_adjustment", store: @adjustment.store)

      reversal = Inventory::ReverseAdjustment.call(
        adjustment: @adjustment,
        actor: current_user,
        source_id: params.require(:command_token),
        idempotency_key: params.require(:idempotency_key),
        notes: params.require(:notes),
        allow_backdate: effective_permissions.include?("inventory.backdate")
      )
      redirect_to admin_inventory_adjustment_path(reversal), notice: "Adjustment reversed."
    rescue Inventory::ReverseAdjustment::Error => e
      redirect_to reverse_admin_inventory_adjustment_path(@adjustment), alert: e.message
    end

    private

    def set_adjustment
      @adjustment = InventoryAdjustment.find(params[:id])
    end

    def resolve_store
      if params[:store_id].present?
        Store.find(params[:store_id])
      else
        current_store
      end
    end

    def resolve_product_variant(raw)
      resolve_product_variant!(raw)
    rescue ArgumentError, ActiveRecord::RecordNotFound
      nil
    end

    def resolve_product_variant!(raw)
      value = raw.to_s.strip
      raise ArgumentError, "variant identifier is required" if value.blank?

      if value.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
        return ProductVariant.find(value)
      end

      result = Identifiers::Lookup.call(value)
      case result.status
      when :variant
        result.variant
      when :inventory_unit
        result.variant || raise(ArgumentError, "Variant not found")
      when :product
        # Adjustments may target discontinued or unsellable merchandise, so POS
        # sellability must not filter these candidates.
        variants = result.product.product_variants.to_a
        raise ArgumentError, "Product has no variants; enter a variant SKU" if variants.empty?
        raise ArgumentError, "Multiple variants match; enter a specific variant SKU" if variants.many?

        variants.first
      when :multiple_products
        raise ArgumentError, "Multiple products share that lookup code; enter a specific variant SKU"
      else
        raise ArgumentError, result.message.presence || "Variant not found"
      end
    end

    def occurred_at_param
      return unless effective_permissions.include?("inventory.backdate")

      params[:occurred_at].presence
    end

    def parse_money(raw)
      return if raw.blank?

      Money::ParseCents.call(raw)
    end
  end
end
