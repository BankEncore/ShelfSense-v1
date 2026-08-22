# frozen_string_literal: true

module Admin
  class PurchaseOrdersController < BaseController
    before_action -> { require_permission!("orders.view") }, only: %i[index show]
    before_action -> { require_permission!("purchase_orders.cancel") }, only: :cancel_line
    before_action -> { require_permission!("purchase_orders.send") }, only: :acknowledge_line
    before_action :set_purchase_order, only: %i[show cancel_line acknowledge_line]
    before_action :set_line, only: %i[cancel_line acknowledge_line]

    def index
      status = params[:status].presence
      scope = PurchaseOrder.includes(:supplier, :store).admin_ordered
      scope = scope.for_store(current_store) if current_store.present?
      scope = scope.with_status(status) if status.present? && PurchaseOrder::STATUSES.include?(status)
      @status_filter = status
      @purchase_orders = scope.limit(200)
    end

    def show
      @lines = @purchase_order.purchase_order_lines
        .includes(:line_state, :cancellations, order: :customer_request, product_variant: :product)
        .order(:created_at)
      @suppliers = Supplier.active.admin_ordered
    end

    def cancel_line
      re_source = ActiveModel::Type::Boolean.new.cast(params[:re_source])
      replacement_supplier = if re_source && params[:replacement_supplier_id].present?
        Supplier.active.find(params[:replacement_supplier_id])
      end

      result = Purchasing::CancelPurchaseOrderQuantity.call(
        purchase_order_line: @line,
        actor: current_user,
        quantity: params.require(:quantity),
        source: params.fetch(:source, "buyer"),
        reason: params.require(:reason),
        re_source: re_source,
        replacement_supplier: replacement_supplier,
        expected_unit_cost_cents: optional_cents(params[:expected_unit_cost_cents])
      )

      notice = "Cancelled #{params[:quantity]} on line."
      if result[:replacement_order]
        notice += " Replacement order ##{result[:replacement_order].number} created."
      end
      redirect_to admin_purchase_order_path(@purchase_order), notice: notice
    rescue Purchasing::Error, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
      redirect_to admin_purchase_order_path(@purchase_order), alert: e.message
    end

    def acknowledge_line
      Purchasing::RecordLineAcknowledgment.call(
        purchase_order_line: @line,
        actor: current_user,
        confirmed_quantity: params.key?(:confirmed_quantity) ? params[:confirmed_quantity] : :__omit__,
        backordered_quantity: params.key?(:backordered_quantity) ? params[:backordered_quantity] : :__omit__,
        expected_on: params.key?(:expected_on) ? params[:expected_on] : :__omit__,
        supplier_reference: params.key?(:supplier_reference) ? params[:supplier_reference] : :__omit__,
        notes: params.key?(:notes) ? params[:notes] : :__omit__,
        expected_lock_version: params[:lock_version]
      )
      redirect_to admin_purchase_order_path(@purchase_order), notice: "Acknowledgment saved."
    rescue Purchasing::Error, ActiveRecord::RecordInvalid => e
      redirect_to admin_purchase_order_path(@purchase_order), alert: e.message
    rescue ActiveRecord::StaleObjectError
      redirect_to admin_purchase_order_path(@purchase_order),
                  alert: "This acknowledgment was changed by someone else. Reload and try again."
    end

    private

    def set_purchase_order
      @purchase_order = PurchaseOrder.find(params[:id])
      permission =
        case action_name
        when "cancel_line" then "purchase_orders.cancel"
        when "acknowledge_line" then "purchase_orders.send"
        else "orders.view"
        end
      return unless authorize!(permission, store: @purchase_order.store)
    end

    def set_line
      @line = @purchase_order.purchase_order_lines.find(params[:line_id])
    end

    def optional_cents(value)
      return if value.blank?

      Integer(value)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
