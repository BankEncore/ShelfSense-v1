# frozen_string_literal: true

module Ops
  class ReceivingController < BaseController
    before_action -> { require_permission!("purchase_receipts.view") }, only: %i[index show]
    before_action -> { require_permission!("purchase_receipts.manage") }, only: %i[create add_line update update_line]
    before_action -> { require_permission!("purchase_receipts.post") }, only: %i[review post]
    before_action -> { require_permission!("purchase_receipts.correct") }, only: %i[reverse reverse_line correct_cost]
    before_action :set_receipt, only: %i[show add_line update update_line review post reverse reverse_line correct_cost]

    def index
      @draft_receipts = PurchaseReceipt.draft
        .for_store(current_store)
        .includes(:supplier, :purchase_receipt_lines)
        .order(created_at: :desc)
      @suppliers = Supplier.active.admin_ordered
    end

    def show
      @lines = @receipt.purchase_receipt_lines
        .includes(
          :corrections,
          purchase_order_line: { order: :customer_request, product_variant: :product, purchase_order: [] },
          product_variant: :product
        )
        .order(:created_at)
      @open_po_lines = open_po_lines_for(@receipt) if @receipt.draft?
      @can_correct = effective_permissions.include?("purchase_receipts.correct")
      @can_compensate = effective_permissions.include?("purchase_receipts.compensate")
    end

    def create
      receipt = Purchasing::CreateDraftPurchaseReceipt.call(
        store: current_store,
        supplier: Supplier.find(params.require(:supplier_id)),
        actor: current_user,
        received_at: parse_time(params[:received_at]),
        supplier_document_number: params[:supplier_document_number],
        supplier_document_date: params[:supplier_document_date].presence,
        freight_cents: params[:freight_cents].presence || 0,
        handling_cents: params[:handling_cents].presence || 0,
        supplier_tax_cents: params[:supplier_tax_cents].presence || 0,
        miscellaneous_charges_cents: params[:miscellaneous_charges_cents].presence || 0,
        charge_notes: params[:charge_notes],
        notes: params[:notes]
      )
      redirect_to ops_receiving_path(receipt), notice: "Draft receipt created."
    rescue Purchasing::Error, ActiveRecord::RecordInvalid => e
      redirect_to ops_receiving_index_path, alert: e.message
    end

    def update
      raise Purchasing::Error, "only draft receipts can be edited" unless @receipt.draft?

      @receipt.update!(
        received_at: parse_time(params[:received_at]) || @receipt.received_at,
        supplier_document_number: params[:supplier_document_number],
        supplier_document_date: params[:supplier_document_date].presence,
        freight_cents: integer_param(params[:freight_cents], @receipt.freight_cents),
        handling_cents: integer_param(params[:handling_cents], @receipt.handling_cents),
        supplier_tax_cents: integer_param(params[:supplier_tax_cents], @receipt.supplier_tax_cents),
        miscellaneous_charges_cents: integer_param(params[:miscellaneous_charges_cents], @receipt.miscellaneous_charges_cents),
        charge_notes: params[:charge_notes],
        notes: params[:notes]
      )
      redirect_to ops_receiving_path(@receipt), notice: "Receipt updated."
    rescue Purchasing::Error, ActiveRecord::RecordInvalid => e
      redirect_to ops_receiving_path(@receipt), alert: e.message
    end

    def add_line
      po_line = PurchaseOrderLine
        .joins(:purchase_order)
        .where(purchase_orders: { store_id: current_store.id, supplier_id: @receipt.supplier_id })
        .find(params.require(:purchase_order_line_id))

      Purchasing::AddPurchaseReceiptLine.call(
        purchase_receipt: @receipt,
        purchase_order_line: po_line,
        actor: current_user,
        received_quantity: params.require(:received_quantity),
        actual_unit_cost_cents: params.require(:actual_unit_cost_cents),
        notes: params[:notes],
        expected_lock_version: params[:lock_version]
      )
      redirect_to ops_receiving_path(@receipt), notice: "Line added."
    rescue Purchasing::Error, ActiveRecord::RecordInvalid => e
      redirect_to ops_receiving_path(@receipt), alert: e.message
    rescue ActiveRecord::StaleObjectError
      redirect_to ops_receiving_path(@receipt),
                  alert: "This receipt was changed by someone else. Reload and try again."
    end

    def update_line
      line = @receipt.purchase_receipt_lines.find(params[:line_id])
      Purchasing::AddPurchaseReceiptLine.call(
        purchase_receipt: @receipt,
        purchase_order_line: line.purchase_order_line,
        actor: current_user,
        received_quantity: params.require(:received_quantity),
        actual_unit_cost_cents: params.require(:actual_unit_cost_cents),
        notes: params.key?(:notes) ? params[:notes] : line.notes,
        expected_lock_version: params[:lock_version]
      )
      redirect_to ops_receiving_path(@receipt), notice: "Line updated."
    rescue Purchasing::Error, ActiveRecord::RecordInvalid => e
      redirect_to ops_receiving_path(@receipt), alert: e.message
    rescue ActiveRecord::StaleObjectError
      redirect_to ops_receiving_path(@receipt),
                  alert: "This receipt was changed by someone else. Reload and try again."
    end

    def review
      unless @receipt.draft?
        redirect_to ops_receiving_path(@receipt), alert: "Only draft receipts can be reviewed for posting."
        return
      end

      @lines = @receipt.purchase_receipt_lines
        .includes(purchase_order_line: { order: :customer_request, product_variant: :product, purchase_order: [] })
        .order(:created_at)
      @preview_lines = @lines.map { |line| preview_line(line) }
    end

    def post
      allow_backdate = effective_permissions.include?("purchase_receipts.backdate")

      receipt = Purchasing::PostPurchaseReceipt.call(
        purchase_receipt: @receipt,
        actor: current_user,
        idempotency_key: params[:idempotency_key].presence || SecureRandom.uuid_v7,
        allow_backdate: allow_backdate,
        expected_lock_version: params[:lock_version]
      )
      redirect_to ops_receiving_path(receipt), notice: "Receipt ##{receipt.number} posted."
    rescue Purchasing::Error, ActiveRecord::RecordInvalid => e
      redirect_to ops_receiving_review_path(@receipt), alert: e.message
    rescue ActiveRecord::StaleObjectError
      redirect_to ops_receiving_path(@receipt),
                  alert: "This receipt was changed by someone else. Reload and try again."
    end

    def reverse
      Purchasing::ReversePurchaseReceipt.call(
        purchase_receipt: @receipt,
        actor: current_user,
        reason: params.require(:reason),
        idempotency_key: params[:idempotency_key].presence || SecureRandom.uuid_v7
      )
      redirect_to ops_receiving_path(@receipt), notice: "Receipt reversed."
    rescue Purchasing::Error, ActiveRecord::RecordInvalid => e
      redirect_to ops_receiving_path(@receipt), alert: e.message
    end

    def reverse_line
      line = @receipt.purchase_receipt_lines.find(params[:line_id])
      Purchasing::ReversePurchaseReceiptLine.call(
        purchase_receipt_line: line,
        actor: current_user,
        reason: params.require(:reason),
        quantity: params[:quantity].presence,
        authorize_compensate: compensate_authorized?,
        idempotency_key: params[:idempotency_key].presence || SecureRandom.uuid_v7
      )
      redirect_to ops_receiving_path(@receipt), notice: "Receipt line reversed."
    rescue Purchasing::Error, ActiveRecord::RecordInvalid => e
      redirect_to ops_receiving_path(@receipt), alert: e.message
    end

    def correct_cost
      line = @receipt.purchase_receipt_lines.find(params[:line_id])
      Purchasing::CorrectPurchaseReceiptLineCost.call(
        purchase_receipt_line: line,
        actor: current_user,
        reason: params.require(:reason),
        corrected_unit_cost_cents: params[:corrected_unit_cost_cents],
        value_delta_cents: params[:value_delta_cents],
        idempotency_key: params[:idempotency_key].presence || SecureRandom.uuid_v7
      )
      redirect_to ops_receiving_path(@receipt), notice: "Cost correction posted."
    rescue Purchasing::Error, ActiveRecord::RecordInvalid => e
      redirect_to ops_receiving_path(@receipt), alert: e.message
    end

    private

    def set_receipt
      @receipt = PurchaseReceipt.for_store(current_store).find(params[:id])
    end

    def compensate_authorized?
      ActiveModel::Type::Boolean.new.cast(params[:authorize_compensate]) &&
        effective_permissions.include?("purchase_receipts.compensate")
    end

    def open_po_lines_for(receipt)
      PurchaseOrderLine
        .joins(:purchase_order)
        .includes(:order, :cancellations, :purchase_receipt_lines, product_variant: :product, purchase_order: [])
        .where(purchase_orders: {
          store_id: receipt.store_id,
          supplier_id: receipt.supplier_id,
          status: %w[sent closed]
        })
        .order(Arel.sql("purchase_orders.number NULLS LAST"), :created_at)
        .to_a
        .select do |line|
          line.open_quantity.positive? ||
            receipt.purchase_receipt_lines.any? { |rl| rl.purchase_order_line_id == line.id }
        end
    end

    def preview_line(line)
      open_qty = line.purchase_order_line.open_quantity
      matched = [ line.received_quantity, [ open_qty, 0 ].max ].min
      unplanned = line.received_quantity - matched
      request = line.purchase_order_line.order.customer_request
      allocates = matched.positive? &&
        request.present? &&
        !request.cancelled? &&
        !request.completed? &&
        %w[ordered special_order_pending].include?(request.status) &&
        request.active_allocation.blank?

      {
        line: line,
        open_quantity: open_qty,
        matched_quantity: matched,
        unplanned_quantity: unplanned,
        allocates: allocates,
        request: request
      }
    end

    def parse_time(value)
      return if value.blank?
      return value if value.acts_like?(:time)

      Time.zone.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def integer_param(value, default)
      return default if value.blank?

      Integer(value)
    rescue ArgumentError, TypeError
      default
    end
  end
end
