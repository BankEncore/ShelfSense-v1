# frozen_string_literal: true

module Ops
  class DraftPosController < BaseController
    before_action -> { require_permission!("orders.view") }, only: %i[index show]
    before_action -> { require_permission!("orders.manage") }, only: %i[add_line update_line]
    before_action -> { require_permission!("purchase_orders.send") }, only: %i[generate send_po return_to_draft]
    before_action :set_purchase_order, only: %i[show add_line update_line generate send_po return_to_draft]

    def index
      @draft_pos = PurchaseOrder.draft
        .for_store(current_store)
        .includes(:supplier, :purchase_order_lines)
        .order(:created_at)
    end

    def show
      unless @purchase_order.draft?
        redirect_to admin_purchase_order_path(@purchase_order) and return
      end

      @lines = @purchase_order.purchase_order_lines
        .includes(order: :customer_request, product_variant: :product)
        .order(:created_at)
    end

    def add_line
      variant = resolve_variant!
      order = Purchasing::AddStockOrderToDraftPo.call(
        purchase_order: @purchase_order,
        product_variant: variant,
        actor: current_user,
        quantity: params.fetch(:quantity, 1),
        notes: params[:notes],
        expected_unit_cost_cents: optional_cents(params[:expected_unit_cost_cents]),
        expected_lock_version: params[:lock_version]
      )
      redirect_to ops_purchase_order_path(@purchase_order),
                  notice: "Added stock order ##{order.number}."
    rescue Purchasing::Error, ActiveRecord::RecordInvalid => e
      redirect_to ops_purchase_order_path(@purchase_order), alert: e.message
    rescue ActiveRecord::StaleObjectError
      redirect_to ops_purchase_order_path(@purchase_order),
                  alert: "This draft PO was changed by someone else. Reload and try again."
    end

    def update_line
      line = @purchase_order.purchase_order_lines.find(params[:line_id])
      Purchasing::UpdateDraftOrder.call(
        order: line.order,
        actor: current_user,
        quantity: params[:quantity].presence,
        notes: params.key?(:notes) ? params[:notes] : :__omit__,
        expected_unit_cost_cents: optional_cents(params[:expected_unit_cost_cents]),
        expected_lock_version: params[:lock_version]
      )
      redirect_to ops_purchase_order_path(@purchase_order), notice: "Line updated."
    rescue Purchasing::Error, ActiveRecord::RecordInvalid => e
      redirect_to ops_purchase_order_path(@purchase_order), alert: e.message
    rescue ActiveRecord::StaleObjectError
      redirect_to ops_purchase_order_path(@purchase_order),
                  alert: "This order was changed by someone else. Reload and try again."
    end

    def generate
      Purchasing::GeneratePurchaseOrder.call(
        purchase_order: @purchase_order,
        actor: current_user,
        expected_lock_version: params[:lock_version]
      )
      redirect_to ops_purchase_order_path(@purchase_order), notice: "Purchase order generated."
    rescue Purchasing::Error, ActiveRecord::RecordInvalid => e
      redirect_to ops_purchase_order_path(@purchase_order), alert: e.message
    rescue ActiveRecord::StaleObjectError
      redirect_to ops_purchase_order_path(@purchase_order),
                  alert: "This draft PO was changed by someone else. Reload and try again."
    end

    def send_po
      Purchasing::SendPurchaseOrder.call(
        purchase_order: @purchase_order,
        actor: current_user,
        transmission_method: params.require(:transmission_method),
        expected_lock_version: params[:lock_version]
      )
      redirect_to admin_purchase_order_path(@purchase_order), notice: "Purchase order sent."
    rescue Purchasing::Error, ActiveRecord::RecordInvalid => e
      redirect_to ops_purchase_order_path(@purchase_order), alert: e.message
    rescue ActiveRecord::StaleObjectError
      redirect_to ops_purchase_order_path(@purchase_order),
                  alert: "This draft PO was changed by someone else. Reload and try again."
    end

    def return_to_draft
      Purchasing::ReturnPurchaseOrderToDraft.call(
        purchase_order: @purchase_order,
        actor: current_user,
        expected_lock_version: params[:lock_version]
      )
      redirect_to ops_purchase_order_path(@purchase_order), notice: "Returned to draft for further edits."
    rescue Purchasing::Error, ActiveRecord::RecordInvalid => e
      redirect_to ops_purchase_order_path(@purchase_order), alert: e.message
    rescue ActiveRecord::StaleObjectError
      redirect_to ops_purchase_order_path(@purchase_order),
                  alert: "This draft PO was changed by someone else. Reload and try again."
    end

    private

    def set_purchase_order
      @purchase_order = PurchaseOrder.for_store(current_store).find(params[:id])
    end

    def resolve_variant!
      if params[:product_variant_id].present?
        variant = ProductVariant.find(params[:product_variant_id])
      else
        identifier = params[:identifier].to_s.strip
        raise Purchasing::Error, "identifier or product variant is required" if identifier.blank?

        result = Identifiers::Lookup.call(identifier)
        variant = case result.status
        when :variant
          result.variant
        when :product
          eligible = result.product.product_variants.select { |v| v.standard? && v.status == "active" && v.inventory_mode == "inventory" }
          raise Purchasing::Error, "select a Standard variant" unless eligible.one?

          eligible.first
        when :inventory_unit
          raise Purchasing::Error, "Used units cannot be added to a purchase order"
        else
          raise Purchasing::Error, result.message.presence || "merchandise not found"
        end
      end

      raise Purchasing::Error, "Used variants cannot be ordered from suppliers" if variant.used?
      variant
    end

    def optional_cents(value)
      return if value.blank?

      Integer(value)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
