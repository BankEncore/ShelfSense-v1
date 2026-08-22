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
    rescue Money::ParseCents::Error => e
      render_mutation_failure(:add_line, e, field: :expected_unit_cost_cents)
    rescue Purchasing::Error, ActiveRecord::RecordInvalid => e
      render_mutation_failure(:add_line, e, field: :identifier)
    rescue ActiveRecord::StaleObjectError => e
      render_mutation_failure(:add_line, e, field: :identifier, stale: true)
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
    rescue Money::ParseCents::Error => e
      render_mutation_failure(:update_line, e, field: :expected_unit_cost_cents, row_id: params[:line_id])
    rescue Purchasing::Error, ActiveRecord::RecordInvalid => e
      render_mutation_failure(:update_line, e, field: :quantity, row_id: params[:line_id])
    rescue ActiveRecord::StaleObjectError => e
      render_mutation_failure(:update_line, e, field: :quantity, row_id: params[:line_id], stale: true)
    end

    def generate
      Purchasing::GeneratePurchaseOrder.call(
        purchase_order: @purchase_order,
        actor: current_user,
        expected_lock_version: params[:lock_version]
      )
      redirect_to ops_purchase_order_path(@purchase_order), notice: "Purchase order generated."
    rescue Purchasing::Error, ActiveRecord::RecordInvalid => e
      render_mutation_failure(:generate, e)
    rescue ActiveRecord::StaleObjectError => e
      render_mutation_failure(:generate, e, stale: true)
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
      render_mutation_failure(:send_po, e, field: :transmission_method)
    rescue ActiveRecord::StaleObjectError => e
      render_mutation_failure(:send_po, e, field: :transmission_method, stale: true)
    end

    def return_to_draft
      Purchasing::ReturnPurchaseOrderToDraft.call(
        purchase_order: @purchase_order,
        actor: current_user,
        expected_lock_version: params[:lock_version]
      )
      redirect_to ops_purchase_order_path(@purchase_order), notice: "Returned to draft for further edits."
    rescue Purchasing::Error, ActiveRecord::RecordInvalid => e
      render_mutation_failure(:return_to_draft, e)
    rescue ActiveRecord::StaleObjectError => e
      render_mutation_failure(:return_to_draft, e, stale: true)
    end

    private

    def render_mutation_failure(action, exception, field: nil, row_id: nil, stale: false)
      @submitted = params.to_unsafe_h.slice("identifier", "product_variant_id", "quantity", "expected_unit_cost_cents", "notes", "transmission_method")
      @error_action = action
      @error_field = field
      @selected_row_id = row_id
      @conflict = stale
      @mutation_errors = [ stale ? "This purchase order was changed by someone else." : exception.message ]
      @purchase_order.reload
      @lines = @purchase_order.purchase_order_lines.includes(order: :customer_request, product_variant: :product).order(:created_at)
      render :show, status: :unprocessable_entity
    end

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

      Money::ParseCents.call(value)
    end
  end
end
