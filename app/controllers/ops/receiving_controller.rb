# frozen_string_literal: true

module Ops
  class ReceivingController < BaseController
    before_action -> { require_permission!("purchase_receipts.view") }, only: %i[index show]
    before_action -> { require_permission!("purchase_receipts.manage") }, only: %i[create line_lookup add_line update update_line]
    before_action -> { require_permission!("purchase_receipts.post") }, only: %i[review post]
    before_action -> { require_permission!("purchase_receipts.correct") }, only: %i[reverse reverse_line correct_cost]
    before_action :set_receipt, only: %i[show line_lookup add_line update update_line review post reverse reverse_line correct_cost]

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
      @can_correct = effective_permissions.include?("purchase_receipts.correct")
      @can_compensate = effective_permissions.include?("purchase_receipts.compensate")
    end

    def line_lookup
      unless @receipt.draft?
        render json: { outcome: "ineligible", message: "Only draft receipts can be edited." }, status: :unprocessable_entity
        return
      end

      query = params[:query].to_s.strip
      if query.blank?
        render json: { outcome: "no_match", message: "Enter or scan an identifier." }
        return
      end

      variants, used_variant = lookup_variants(query)
      lines = eligible_open_po_lines(@receipt, variants, query)

      if lines.empty?
        message = if used_variant
          "Used variants are not eligible for purchase-order receiving."
        else
          "No eligible open Standard PO line matches this receipt's store and supplier."
        end
        render json: { outcome: used_variant ? "ineligible" : "no_match", message: message }
      else
        render json: {
          outcome: lines.one? ? "selected" : "multiple",
          matches: lines.map { |line| serialize_lookup_line(line) }
        }
      end
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
    rescue Purchasing::Error, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
      @submitted = params.to_unsafe_h.slice("supplier_id", "received_at", "supplier_document_number")
      @error_action = :create
      @error_field = :supplier_id
      @mutation_errors = [e.message]
      @draft_receipts = PurchaseReceipt.draft.for_store(current_store).includes(:supplier, :purchase_receipt_lines).order(created_at: :desc)
      @suppliers = Supplier.active.admin_ordered
      render :index, status: :unprocessable_entity
    end

    def update
      Purchasing::UpdateDraftPurchaseReceipt.call(
        purchase_receipt: @receipt,
        actor: current_user,
        expected_lock_version: params[:lock_version],
        received_at: parse_time(params[:received_at]) || :__omit__,
        supplier_document_number: params.key?(:supplier_document_number) ? params[:supplier_document_number] : :__omit__,
        supplier_document_date: params.key?(:supplier_document_date) ? params[:supplier_document_date] : :__omit__,
        freight_cents: params.key?(:freight_cents) ? params[:freight_cents] : :__omit__,
        handling_cents: params.key?(:handling_cents) ? params[:handling_cents] : :__omit__,
        supplier_tax_cents: params.key?(:supplier_tax_cents) ? params[:supplier_tax_cents] : :__omit__,
        miscellaneous_charges_cents: params.key?(:miscellaneous_charges_cents) ? params[:miscellaneous_charges_cents] : :__omit__,
        charge_notes: params.key?(:charge_notes) ? params[:charge_notes] : :__omit__,
        notes: params.key?(:notes) ? params[:notes] : :__omit__
      )
      redirect_to ops_receiving_path(@receipt), notice: "Receipt updated."
    rescue Purchasing::Error, ActiveRecord::RecordInvalid => e
      render_mutation_failure(:update, e, field: :received_at)
    rescue ActiveRecord::StaleObjectError => e
      render_mutation_failure(:update, e, field: :received_at, stale: true)
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
      respond_to do |format|
        format.html { redirect_to ops_receiving_path(@receipt), notice: "Line added." }
        format.turbo_stream do
          load_receipt_lines
          @scan_notice = "Line added. Scanner ready."
          render :add_line
        end
      end
    rescue Purchasing::Error, ActiveRecord::RecordInvalid => e
      render_mutation_failure(:add_line, e, field: :received_quantity, row_id: params[:purchase_order_line_id])
    rescue ActiveRecord::StaleObjectError => e
      render_mutation_failure(:add_line, e, field: :received_quantity, row_id: params[:purchase_order_line_id], stale: true)
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
      render_mutation_failure(:update_line, e, field: :received_quantity, row_id: params[:line_id])
    rescue ActiveRecord::StaleObjectError => e
      render_mutation_failure(:update_line, e, field: :received_quantity, row_id: params[:line_id], stale: true)
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
      render_review_failure(e)
    rescue ActiveRecord::StaleObjectError => e
      render_review_failure(e, stale: true)
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

    def render_mutation_failure(action, exception, field:, row_id: nil, stale: false)
      @submitted = params.to_unsafe_h.slice(
        "received_at", "supplier_document_number", "supplier_document_date", "freight_cents", "handling_cents",
        "supplier_tax_cents", "miscellaneous_charges_cents", "charge_notes", "notes", "purchase_order_line_id",
        "received_quantity", "actual_unit_cost_cents"
      )
      @error_action = action
      @error_field = field
      @selected_row_id = row_id
      @conflict = stale
      @mutation_errors = [stale ? "This receipt was changed by someone else." : exception.message]
      load_receipt_lines
      respond_to do |format|
        format.html { render :show, status: :unprocessable_entity }
        format.turbo_stream { render :mutation_failure, status: :unprocessable_entity }
      end
    end

    def render_review_failure(exception, stale: false)
      @error_action = :post
      @conflict = stale
      @mutation_errors = [stale ? "This receipt was changed by someone else." : exception.message]
      load_receipt_lines
      @preview_lines = @lines.map { |line| preview_line(line) }
      render :review, status: :unprocessable_entity
    end

    def load_receipt_lines
      @receipt.reload
      @lines = @receipt.purchase_receipt_lines
        .includes(
          :corrections,
          purchase_order_line: { order: :customer_request, product_variant: :product, purchase_order: [] },
          product_variant: :product
        )
        .order(:created_at)
    end

    def lookup_variants(query)
      result = Identifiers::Lookup.call(query)
      variants = case result.status
      when :variant, :inventory_unit then [ result.variant ].compact
      when :product then result.variants
      else []
      end

      if variants.empty?
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
        variants = ProductVariant.joins(:product)
          .where("products.name ILIKE :pattern OR products.lookup_code = :code", pattern: pattern, code: Product.canonical_lookup_code(query))
          .limit(50)
          .to_a
      end
      [ variants.select(&:standard?), variants.any?(&:used?) ]
    end

    def eligible_open_po_lines(receipt, variants, query)
      scope = PurchaseOrderLine
        .joins(:purchase_order, :order)
        .left_joins(order: :customer_request)
        .includes(:cancellations, :purchase_receipt_lines, { order: :customer_request }, product_variant: :product, purchase_order: [])
        .where(product_variant_id: variants.map(&:id))
        .where(purchase_orders: { store_id: receipt.store_id, supplier_id: receipt.supplier_id, status: %w[sent closed] })

      # A request number is also a useful receiving search term; preserve all
      # identifier matches while adding an exact customer-request match.
      request_number = Integer(query, exception: false)
      if variants.empty? && request_number
        scope = PurchaseOrderLine
          .joins(:purchase_order, order: :customer_request)
          .includes(:cancellations, :purchase_receipt_lines, { order: :customer_request }, product_variant: :product, purchase_order: [])
          .where(customer_requests: { number: request_number })
          .where(purchase_orders: { store_id: receipt.store_id, supplier_id: receipt.supplier_id, status: %w[sent closed] })
      end

      scope.order(Arel.sql("purchase_orders.number NULLS LAST"), :created_at).to_a.select { |line| line.open_quantity.positive? }
    end

    def serialize_lookup_line(line)
      request = line.order.customer_request
      {
        id: line.id,
        po_number: line.purchase_order.number,
        product: line.product_variant.product.name,
        sku: line.product_variant.sku,
        customer_request: request&.number,
        order_date: line.purchase_order.sent_at&.to_date || line.purchase_order.created_at.to_date,
        open_quantity: line.open_quantity,
        expected_unit_cost_cents: line.expected_unit_cost_cents_snapshot
      }
    end

    def set_receipt
      @receipt = PurchaseReceipt.for_store(current_store).find(params[:id])
    end

    def compensate_authorized?
      ActiveModel::Type::Boolean.new.cast(params[:authorize_compensate]) &&
        effective_permissions.include?("purchase_receipts.compensate")
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
  end
end
