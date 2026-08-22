# frozen_string_literal: true

module Admin
  class PurchaseReceiptsController < BaseController
    before_action -> { require_permission!("purchase_receipts.view") }, only: %i[index show]
    before_action -> { require_permission!("purchase_receipts.correct") }, only: %i[reverse reverse_line correct_cost]
    before_action :set_receipt, only: %i[show reverse reverse_line correct_cost]
    before_action :set_line, only: %i[reverse_line correct_cost]

    def index
      scope = PurchaseReceipt.where(status: %w[posted reversed])
        .includes(:supplier, :store)
        .admin_ordered
      scope = scope.for_store(current_store) if current_store.present?
      @purchase_receipts = scope.limit(200)
    end

    def show
      @lines = @receipt.purchase_receipt_lines
        .includes(
          :corrections,
          purchase_order_line: { order: :customer_request, product_variant: :product, purchase_order: [] },
          product_variant: :product
        )
        .order(:created_at)
      @can_correct = effective_permissions.include?("purchase_receipts.correct")
      @can_compensate = effective_permissions.include?("purchase_receipts.compensate")
    end

    def reverse
      Purchasing::ReversePurchaseReceipt.call(
        purchase_receipt: @receipt,
        actor: current_user,
        reason: params.require(:reason),
        idempotency_key: params[:idempotency_key].presence || SecureRandom.uuid_v7
      )
      redirect_to admin_purchase_receipt_path(@receipt), notice: "Receipt reversed."
    rescue Purchasing::Error, ActiveRecord::RecordInvalid => e
      redirect_to admin_purchase_receipt_path(@receipt), alert: e.message
    end

    def reverse_line
      Purchasing::ReversePurchaseReceiptLine.call(
        purchase_receipt_line: @line,
        actor: current_user,
        reason: params.require(:reason),
        quantity: params[:quantity].presence,
        authorize_compensate: compensate_authorized?,
        idempotency_key: params[:idempotency_key].presence || SecureRandom.uuid_v7
      )
      redirect_to admin_purchase_receipt_path(@receipt), notice: "Receipt line reversed."
    rescue Purchasing::Error, ActiveRecord::RecordInvalid => e
      redirect_to admin_purchase_receipt_path(@receipt), alert: e.message
    end

    def correct_cost
      Purchasing::CorrectPurchaseReceiptLineCost.call(
        purchase_receipt_line: @line,
        actor: current_user,
        reason: params.require(:reason),
        corrected_unit_cost_cents: params[:corrected_unit_cost_cents],
        value_delta_cents: params[:value_delta_cents],
        idempotency_key: params[:idempotency_key].presence || SecureRandom.uuid_v7
      )
      redirect_to admin_purchase_receipt_path(@receipt), notice: "Cost correction posted."
    rescue Purchasing::Error, ActiveRecord::RecordInvalid => e
      redirect_to admin_purchase_receipt_path(@receipt), alert: e.message
    end

    private

    def set_receipt
      @receipt = PurchaseReceipt.find(params[:id])
      permission =
        case action_name
        when "reverse", "reverse_line", "correct_cost" then "purchase_receipts.correct"
        else "purchase_receipts.view"
        end
      return unless authorize!(permission, store: @receipt.store)
    end

    def set_line
      @line = @receipt.purchase_receipt_lines.find(params[:line_id])
    end

    def compensate_authorized?
      ActiveModel::Type::Boolean.new.cast(params[:authorize_compensate]) &&
        effective_permissions.include?("purchase_receipts.compensate")
    end
  end
end
