# frozen_string_literal: true

module Pos
  class WorkspacesController < BaseController
    OVERLAY_ERROR_TARGETS = {
      "controlled_action" => "pos-control-feedback",
      "unlinked_return" => "pos-unlinked-feedback",
      "open_price" => "pos-open-price-feedback",
      "linked_return" => "pos-linked-feedback",
      "stored_value_issuance" => "pos-issuance-feedback",
      "replace_tender" => "pos-edit-tender-feedback",
      "remove_tender" => "pos-remove-tender-feedback",
      "abandon_tender" => "pos-return-to-sale-feedback"
    }.freeze
    APPROVAL_FEEDBACK_ID = "pos-approval-feedback"

    before_action :require_register!, except: :complete
    before_action :prepare_workspace!, except: %i[show continue complete]
    before_action :prepare_session!, only: :continue
    before_action :load_completion_transaction!, only: :complete

    def show
      @session_record = actor_session
      unless @session_record
        redirect_to pos_register_enter_path(register_id: @register.id)
        return
      end

      @transaction = @session_record.pos_transactions.working.first
      unless @transaction
        redirect_to pos_register_enter_path(register_id: @register.id)
        return
      end

      prepare_view_state
      @feedback ||= flash[:alert]
    end

    def merchandise
      rescue_workspace(error_mode: "sale_entry") do
        selling_price_cents = parse_optional_open_price
        @selected_line = Pos::AddMerchandise.call(
          transaction: @transaction,
          actor: current_user,
          expected_lock_version: expected_lock_version,
          identifier: params[:identifier],
          product_variant: find_optional_variant,
          inventory_unit: find_optional_unit,
          selling_price_cents: selling_price_cents,
          quantity: 1
        )
        @transaction.reload
        @ui_mode = "sale_entry"
        respond_workspace
      end
    end

    def pickup_search
      unless Authorization::PermissionEvaluator.allowed?(
        user: current_user,
        permission_key: "customer_requests.pickup",
        store: current_store
      )
        render json: { error: "not authorized" }, status: :forbidden
        return
      end

      rows = Pos::SearchAvailableCustomerRequests.call(store: current_store, query: params[:q])
      render json: {
        results: rows.map do |row|
          {
            customer_request_id: row.customer_request.id,
            allocation_id: row.allocation.id,
            request_number: row.request_number,
            customer_name: row.customer_name,
            customer_phone: row.customer_phone,
            merchandise_label: row.merchandise_label,
            allocation_type: row.allocation_type,
            unit_identifier: row.unit_identifier,
            label: "Req ##{row.request_number} · #{row.customer_name} · #{row.merchandise_label}"
          }
        end
      }
    end

    def pickup
      rescue_workspace(error_mode: "sale_entry") do
        request = CustomerRequest.for_store(current_store).find(params.require(:customer_request_id))
        @selected_line = Pos::AddPickupMerchandise.call(
          transaction: @transaction,
          actor: current_user,
          expected_lock_version: expected_lock_version,
          customer_request: request
        )
        @transaction.reload
        @ui_mode = "sale_entry"
        respond_workspace
      end
    end

    def resolve
      result = Pos::ResolveMerchandiseForSale.call(
        store: current_store,
        identifier: params[:identifier],
        variant: find_optional_variant,
        inventory_unit: find_optional_unit,
        product: find_optional_product,
        current_transaction: @transaction
      )
      render json: serialize_resolution(result)
    end

    def search
      query = params[:q].presence
      sku = params[:sku].presence || query
      name = params[:name].presence || query
      rows = Pos::SearchMerchandise.call(store: current_store, sku: sku, name: name)
      render json: { results: rows.map { |row| serialize_search_row(row) } }
    end

    def linked_return_lookup
      result = Pos::LookupLinkedReturn.call(
        store: current_store,
        query: params[:q],
        transaction_id: params[:transaction_id],
        current_transaction: @transaction
      )
      render json: serialize_linked_return(result)
    end

    def linked_return
      rescue_workspace(error_mode: "sale_entry") do
        original = PosTransactionLine.find(params.require(:original_line_id))
        @selected_line = Pos::AddLinkedReturnLine.call(
          transaction: @transaction,
          actor: current_user,
          expected_lock_version: expected_lock_version,
          original_line: original,
          quantity: params[:quantity].presence || 1,
          reason_code: params.require(:reason_code),
          reason_note: params[:reason_note]
        )
        @transaction.reload
        @ui_mode = "sale_entry"
        respond_workspace
      end
    end

    def open_price
      rescue_workspace(error_mode: "sale_entry") do
        line = find_line!
        cents = Money::ParseCents.call(params[:selling_price])
        raise Pos::Error, "selling price is required" if cents.nil?

        @selected_line = Pos::UpdateOpenPrice.call(
          transaction: @transaction,
          line: line,
          actor: current_user,
          expected_lock_version: expected_lock_version,
          selling_price_cents: cents
        )
        @transaction.reload
        @ui_mode = "sale_entry"
        respond_workspace
      end
    end

    def quantity
      rescue_workspace(error_mode: "quantity") do
        line = find_line!
        @selected_line = Pos::ChangeQuantity.call(
          transaction: @transaction,
          line: line,
          actor: current_user,
          expected_lock_version: expected_lock_version,
          quantity: params.require(:quantity)
        )
        @transaction.reload
        @ui_mode = "sale_entry"
        respond_workspace
      end
    end

    def remove
      rescue_workspace(error_mode: "sale_entry") do
        line = find_line!
        previous = previous_line(line)
        Pos::RemoveWorkingLine.call(
          transaction: @transaction,
          line: line,
          actor: current_user,
          expected_lock_version: expected_lock_version
        )
        @transaction.reload
        @selected_line = previous && @transaction.pos_transaction_lines.find_by(id: previous.id)
        @ui_mode = "sale_entry"
        respond_workspace
      end
    end

    def controlled_action
      rescue_workspace(error_mode: "sale_entry") do
        line = find_line!
        @selected_line = Pos::ExecuteControlledAction.call(
          transaction: @transaction,
          actor: current_user,
          expected_lock_version: expected_lock_version,
          line: line,
          action_type: params.require(:action_type),
          operation: params.require(:operation),
          reason_code: params[:reason_code],
          reason_note: params[:reason_note],
          **controlled_action_commercial_attrs,
          approver_username: params[:approver_username],
          approver_password: params[:approver_password]
        )
        @transaction.reload
        @ui_mode = "sale_entry"
        respond_workspace
      end
    end

    def unlinked_return_lookup
      Pos::Support.authorize!(current_user, current_store)
      result = Pos::ResolveUnlinkedReturnMerchandise.call(
        identifier: params[:identifier],
        store: current_store,
        product: find_optional_product,
        variant: find_optional_variant,
        inventory_unit: find_optional_unit
      )
      render json: serialize_unlinked_resolution(result)
    rescue Pos::Denied
      render json: { error: "You are not authorized to perform that action." }, status: :forbidden
    rescue Pos::InvalidatedDialogBasis => e
      render json: { outcome: "unavailable", error: e.message, message: e.message }, status: :unprocessable_entity
    rescue Identifiers::NormalizationError, Pos::Error => e
      render json: { outcome: "unavailable", error: e.message, message: e.message }, status: :unprocessable_entity
    end

    def unlinked_return
      rescue_workspace(error_mode: "sale_entry") do
        @selected_line = Pos::ExecuteUnlinkedReturn.call(
          transaction: @transaction,
          actor: current_user,
          expected_lock_version: expected_lock_version,
          identifier: params.require(:identifier),
          quantity: params[:quantity].presence || 1,
          reason_code: params.require(:reason_code),
          reason_note: params[:reason_note],
          requested_return_unit_price_cents: parse_optional_cents(params.require(:return_price)),
          approver_username: params[:approver_username],
          approver_password: params[:approver_password],
          expected_product_variant_id: params[:expected_product_variant_id],
          expected_inventory_unit_id: params[:expected_inventory_unit_id],
          expected_reference_unit_price_cents: params[:expected_reference_unit_price_cents],
          expected_tax_class_id: params[:expected_tax_class_id],
          product_id: params[:product_id],
          product_variant_id: params[:product_variant_id],
          inventory_unit_id: params[:inventory_unit_id]
        )
        @transaction.reload
        @ui_mode = "sale_entry"
        respond_workspace
      end
    end

    def abandon_tender
      rescue_workspace(error_mode: "derive") do
        Pos::ReturnToSaleClearTenders.call(
          transaction: @transaction,
          actor: current_user,
          expected_lock_version: expected_lock_version,
          operation_id: params.require(:operation_id)
        )
        @transaction.reload
        @ui_mode = "sale_entry"
        respond_workspace
      end
    end

    def cancel
      rescue_workspace(error_mode: "sale_entry") do
        Pos::CancelTransaction.call(
          transaction: @transaction,
          actor: current_user,
          expected_lock_version: expected_lock_version
        )
        Pos::ResumeOrStartTransaction.call(session: @session_record, actor: current_user)
        redirect_to pos_register_workspace_path
      end
    end

    def tender
      rescue_workspace(error_mode: "tender") do
        type = selected_tender_type_from_params
        amount = Money::ParseCents.call(params[:tender_amount])
        raise Pos::Error, "tender amount is required" if amount.nil?

        direction = Pos::Support.settlement_direction(@transaction)
        case direction
        when :refund
          if type.stored_value?
            Pos::AddStoredValueRefundTender.call(
              transaction: @transaction,
              actor: current_user,
              expected_lock_version: expected_lock_version,
              tender_type: type,
              amount_cents: amount,
              destination_mode: stored_value_destination_mode(type),
              card_number: params[:card_number],
              gift_card_program: find_optional_gift_card_program
            )
          else
            Pos::AddRefundTender.call(
              transaction: @transaction,
              actor: current_user,
              expected_lock_version: expected_lock_version,
              tender_type: type,
              amount_cents: amount,
              external_reference: params[:external_reference]
            )
          end
        when :payment
          if type.cash?
            Pos::TenderCash.call(
              transaction: @transaction,
              actor: current_user,
              expected_lock_version: expected_lock_version,
              amount_presented_cents: amount
            )
          elsif type.stored_value?
            Pos::AddStoredValueTender.call(
              transaction: @transaction,
              actor: current_user,
              expected_lock_version: expected_lock_version,
              tender_type: type,
              amount_cents: amount,
              card_number: params[:card_number]
            )
          else
            Pos::AddTender.call(
              transaction: @transaction,
              actor: current_user,
              expected_lock_version: expected_lock_version,
              tender_type: type,
              amount_cents: amount,
              external_reference: params[:external_reference]
            )
          end
        else
          raise Pos::Error, "transaction does not require a tender"
        end
        @transaction.reload
        apply_post_tender_view!
        respond_workspace
      end
    end

    def stored_value_issuance
      rescue_workspace(error_mode: "sale_entry") do
        amount = Money::ParseCents.call(params[:issuance_amount])
        raise Pos::Error, "issuance amount is required" if amount.nil?

        Pos::AddStoredValueIssuance.call(
          transaction: @transaction,
          actor: current_user,
          expected_lock_version: expected_lock_version,
          issuance_type: params.require(:issuance_type),
          amount_cents: amount,
          gift_card_program: find_optional_gift_card_program,
          card_number: params[:card_number]
        )
        @transaction.reload
        @ui_mode = "sale_entry"
        respond_workspace
      end
    end

    def remove_stored_value_issuance
      rescue_workspace(error_mode: "sale_entry") do
        issuance = @transaction.pos_stored_value_issuances.find(params.require(:issuance_id))
        Pos::RemoveStoredValueIssuance.call(
          transaction: @transaction,
          actor: current_user,
          expected_lock_version: expected_lock_version,
          issuance: issuance
        )
        @transaction.reload
        @ui_mode = "sale_entry"
        respond_workspace
      end
    end

    def attach_customer
      rescue_workspace(error_mode: "sale_entry") do
        customer = Customer.find_by(id: params.require(:customer_id))
        Pos::AttachCustomer.call(
          transaction: @transaction,
          actor: current_user,
          expected_lock_version: expected_lock_version,
          customer: customer
        )
        @transaction.reload
        @ui_mode = "sale_entry"
        respond_workspace
      end
    end

    def detach_customer
      rescue_workspace(error_mode: "sale_entry") do
        Pos::DetachCustomer.call(
          transaction: @transaction,
          actor: current_user,
          expected_lock_version: expected_lock_version
        )
        @transaction.reload
        @ui_mode = "sale_entry"
        respond_workspace
      end
    end

    def customer_search
      rows = Customers::Search.call(query: params[:q], mode: :operational, limit: 20)
      render json: {
        results: rows.map { |row|
          customer = row.customer
          {
            id: customer.id,
            label: [ customer.display_name, customer.email, customer.phone ].compact.join(" · ")
          }
        }
      }
    end

    def remove_tender
      rescue_workspace(error_mode: "tender") do
        tender = @transaction.pos_tenders.find(params.require(:tender_id))
        tender_index = @transaction.pos_tenders.ordered.to_a.index(tender)
        Pos::RemoveWorkingTender.call(
          transaction: @transaction,
          actor: current_user,
          expected_lock_version: expected_lock_version,
          tender: tender,
          operation_id: params.require(:operation_id)
        )
        @transaction.reload
        remaining = @transaction.pos_tenders.ordered.to_a
        @selected_tender = remaining[tender_index] || remaining[tender_index.to_i - 1]
        @ui_mode = @transaction.pos_tenders.any? ? "tender" : "sale_entry"
        respond_workspace
      end
    end

    def replace_tender
      rescue_workspace(error_mode: "tender") do
        tender = @transaction.pos_tenders.find(params.require(:tender_id))
        amount = Money::ParseCents.call(params[:tender_amount])
        raise Pos::Error, "tender amount is required" if amount.nil?
        presented = Money::ParseCents.call(params[:amount_presented]) if params[:amount_presented].present?

        result = Pos::ReplaceTender.call(
          transaction: @transaction,
          tender: tender,
          actor: current_user,
          operation_id: params.require(:operation_id),
          expected_lock_version: expected_lock_version,
          amount_cents: amount,
          amount_presented_cents: presented,
          external_reference: params[:external_reference]
        )
        @transaction.reload
        @selected_tender = @transaction.pos_tenders.find_by(id: result.tender&.id)
        @ui_mode = "tender"
        respond_workspace
      end
    end

    def complete
      rescue_workspace(error_mode: "derive") do
        if @transaction.completed?
          authorize_completion_transaction!
          redirect_to pos_completed_transaction_path(@transaction)
          return
        end

        expected_total = params.require(:expected_total_cents)
        expected_signed_net = params.require(:expected_signed_net_cents)
        result = Pos::CompleteTransaction.call(
          transaction: @transaction,
          actor: current_user,
          operation_id: params.require(:completion_operation_id),
          expected_lock_version: expected_lock_version,
          expected_total_cents: expected_total,
          expected_signed_net_cents: expected_signed_net
        )
        redirect_to pos_completed_transaction_path(result.transaction)
      end
    end

    def continue
      Pos::ResumeOrStartTransaction.call(session: @session_record, actor: current_user)
      session[:pos_register_id] = @register.id
      redirect_to pos_register_workspace_path
    rescue Pos::Denied, Pos::Error => e
      redirect_to pos_register_enter_path(register_id: @register.id), alert: e.message
    end

    private

    def require_register!
      @register = find_register
      return if @register

      reject_workspace_context!(register_id: nil)
    end

    def prepare_workspace_shell!
      prepare_register_shell!(resolve_register_state(requested_register: @register))
    end

    def actor_session
      PosSession.open.find_by(store: current_store, register: @register, cashier_user: current_user)
    end

    def prepare_session!
      @session_record = actor_session
      return if @session_record

      reject_workspace_context!(register_id: @register&.id)
    end

    def prepare_workspace!
      @session_record = actor_session
      unless @session_record
        reject_workspace_context!(register_id: @register.id)
        return
      end

      @transaction = @session_record.pos_transactions.working.first
      return if @transaction

      reject_workspace_context!(register_id: @register.id)
    end

    def reject_workspace_context!(register_id:)
      if request.format.json?
        render json: { outcome: "unavailable", message: "open a register to continue" }, status: :conflict
      elsif register_id.present?
        redirect_to pos_register_enter_path(register_id: register_id)
      else
        redirect_to pos_register_enter_path
      end
    end

    def load_completion_transaction!
      @transaction = PosTransaction.find_by!(id: params[:transaction_id], store_id: current_store.id)
      raise ActiveRecord::RecordNotFound if @transaction.cancelled?

      @session_record = @transaction.pos_session
      @register = @transaction.register
      session[:pos_register_id] = @register.id
    end

    def authorize_completion_transaction!
      Pos::Support.authorize!(current_user, @transaction.store)
      Pos::Support.require_transaction_cashier!(current_user, @transaction)
    rescue Pos::Denied
      raise ActiveRecord::RecordNotFound
    end

    def prepare_view_state
      prepare_workspace_shell!
      @period = @session_record.reporting_period
      @lines = @transaction.pos_transaction_lines.includes(
        :inventory_unit,
        :pos_controlled_actions,
        :pos_line_tax_components,
        product_variant: [ :product, :merchandise_condition ],
        original_transaction_line: :pos_transaction
      ).to_a
      @tenders = @transaction.pos_tenders.ordered.to_a
      @issuances = @transaction.pos_stored_value_issuances.ordered.includes(:gift_card_program).to_a
      @gift_card_programs = GiftCardProgram.active.admin_ordered.to_a
      @tender = @tenders.find { |tender| pos_workspace_cash_payment?(tender) }
      @settlement_direction = Pos::Support.settlement_direction(@transaction)
      @remaining_payment_cents = Pos::Support.remaining_payment_cents(@transaction)
      @remaining_refund_cents = Pos::Support.remaining_refund_cents(@transaction)
      @cashier_tender_types =
        if @settlement_direction == :refund
          TenderType.refund_selectable.to_a
        else
          TenderType.cashier_selectable.to_a
        end
      @selected_tender_type = resolve_selected_tender_type
      @selected_line ||= default_selected_line
      @selected_tender ||= default_selected_tender
      @tax_classes = TaxClass.active.order(:code)
      @control_policies = {
        "price_override" => Pos::ControlledActionPolicy.result(user: current_user, store: current_store, action_type: "price_override").to_s,
        "line_discount" => Pos::ControlledActionPolicy.result(user: current_user, store: current_store, action_type: "line_discount").to_s,
        "tax_class_override" => Pos::ControlledActionPolicy.result(user: current_user, store: current_store, action_type: "tax_class_override").to_s,
        "unlinked_return" => Pos::ControlledActionPolicy.result(user: current_user, store: current_store, action_type: "unlinked_return").to_s
      }
      @pickup_allowed = Authorization::PermissionEvaluator.allowed?(
        user: current_user,
        permission_key: "customer_requests.pickup",
        store: current_store
      )
      @feedback ||= flash[:alert].presence || flash.now[:alert].presence
      @command_value ||= nil
      if Pos::Support.exact_settlement?(@transaction)
        mint_or_restore_completion!
        if even_exchange_pending?
          @ui_mode ||= "sale_entry"
          @auto_complete = false
        else
          apply_completion_view_state
        end
      elsif @tenders.any?
        @ui_mode ||= "tender"
        @auto_complete = false
      else
        @ui_mode ||= "sale_entry"
        @auto_complete = false
      end
      @workspace = build_workspace_presenter
    end

    def build_workspace_presenter
      Pos::WorkspacePresenter.call(
        transaction: @transaction,
        lines: @lines,
        tenders: @tenders,
        issuances: @issuances,
        selected_line: @selected_line,
        selected_tender_type: @selected_tender_type,
        selected_tender: @selected_tender,
        ui_mode: @ui_mode,
        settlement_direction: @settlement_direction,
        remaining_payment_cents: @remaining_payment_cents,
        remaining_refund_cents: @remaining_refund_cents,
        command_value: @command_value,
        feedback: @feedback,
        action_capabilities: {
          pickup_available: @pickup_allowed,
          gift_card_programs_available: @gift_card_programs.any?,
          close_session_available: @ui_mode == "sale_entry" && @lines.empty? && @tenders.empty? && @issuances.empty?,
          issuance_remove_available: @ui_mode == "sale_entry"
        }
      )
    end

    def apply_completion_view_state
      case @completion_status
      when "pending"
        @ui_mode ||= "completion_pending"
        @auto_complete = true
      when "in_flight"
        if completion_lease_active?
          @ui_mode ||= "completion_pending"
          @auto_complete = false
          @feedback ||= "Completion is still processing"
        else
          @ui_mode ||= "completion_failed"
          @auto_complete = false
        end
      when "failed"
        @ui_mode ||= "completion_failed"
        @auto_complete = false
      else
        @ui_mode ||= "completion_pending"
        @auto_complete = false
      end
    end

    def completion_lease_active?
      expires_at = @completion_operation&.lease_expires_at
      expires_at.present? && expires_at >= Time.current
    end

    def mint_or_restore_completion!
      found = Pos::FindCompletionOperation.call(transaction: @transaction, actor: current_user)
      if found
        @completion_operation = found
        @completion_operation_id = found.id
        @completion_status = found.status
      else
        @completion_operation = nil
        @completion_operation_id = SecureRandom.uuid_v7
        @completion_status = "pending"
      end
    end

    def respond_workspace
      prepare_view_state
      respond_to do |format|
        format.turbo_stream { render "pos/workspaces/update" }
        format.html { render :show }
      end
    end

    def rescue_workspace(error_mode: "sale_entry")
      yield
    rescue Pos::ApproverAuthenticationFailed, Pos::ApproverNotAuthorized, Pos::SelfApprovalProhibited => e
      # Safety net if a service raises typed approver errors without converting first.
      recover_from_overlay_failure(Pos::OverlayFailure.from_approver_error(e), error_mode)
    rescue Pos::Denied
      redirect_to root_path, alert: "You are not authorized to perform that action."
    rescue Pos::OverlayFailure => e
      recover_from_overlay_failure(e, error_mode)
    rescue Pos::StaleObject
      # Stale working state replaces the workspace (packet: proposed values against a
      # changed line are unsafe). Cashier reopens the action on the refreshed line.
      recover_from_overlay_failure(Pos::OverlayFailure.stale, error_mode, persist_overlay: false)
    rescue Pos::InvalidatedDialogBasis => e
      recover_from_overlay_failure(Pos::OverlayFailure.parent_validation(e.message), error_mode, persist_overlay: false)
    rescue Money::ParseCents::Error, Pos::Error => e
      recover_from_overlay_failure(Pos::OverlayFailure.parent_validation(e.message), error_mode)
    end

    def recover_from_overlay_failure(failure, error_mode, persist_overlay: nil)
      @overlay_failure = failure
      @feedback = failure.message
      @transaction.reload
      @command_value = params[:identifier] || params[:quantity] || params[:tender_amount]
      if @transaction.completed?
        redirect_to pos_completed_transaction_path(@transaction)
        return
      end

      persist = persist_overlay.nil? ? overlay_error_dom_id.present? : persist_overlay
      if persist
        respond_overlay_error(error_mode)
        return
      end

      apply_error_mode(error_mode)
      respond_workspace
    end

    def recover_from_workspace_error(message, error_mode, persist_overlay: persist_overlay_error?)
      recover_from_overlay_failure(Pos::OverlayFailure.parent_validation(message), error_mode, persist_overlay: persist_overlay)
    end

    def persist_overlay_error?
      overlay_error_dom_id.present?
    end

    def overlay_error_dom_id
      failure = @overlay_failure
      if failure&.authorization?
        return APPROVAL_FEEDBACK_ID
      end

      return OVERLAY_ERROR_TARGETS[action_name] if OVERLAY_ERROR_TARGETS.key?(action_name)
      return "pos-open-price-feedback" if action_name == "merchandise" && params[:selling_price].present?

      nil
    end

    def respond_overlay_error(error_mode)
      @overlay_error_dom_id = overlay_error_dom_id
      @overlay_failure ||= Pos::OverlayFailure.parent_validation(@feedback)
      respond_to do |format|
        format.turbo_stream { render "pos/workspaces/dialog_error", status: :unprocessable_entity }
        format.html do
          apply_error_mode(error_mode)
          prepare_view_state
          render :show
        end
      end
    end

    def apply_error_mode(error_mode)
      return if error_mode == "derive"
      if Pos::Support.exact_settlement?(@transaction)
        return unless @transaction.even_exchange?
      end

      @ui_mode = error_mode
    end

    def even_exchange_pending?
      @transaction.even_exchange? && @completion_status == "pending"
    end

    def controlled_action_commercial_attrs
      return {} if params[:operation].to_s == "remove"

      case params[:action_type].to_s
      when "price_override"
        { selling_unit_price_cents: parse_optional_cents(params[:selling_price]) }
      when "line_discount"
        { discount_basis_points: parse_discount_basis_points }
      when "tax_class_override"
        { tax_class_id: params[:tax_class_id] }
      else
        {}
      end
    end

    def parse_optional_cents(value)
      return if value.blank?

      Money::ParseCents.call(value)
    end

    def parse_discount_basis_points
      return parse_optional_cents(params[:discount_percent]) if params[:discount_percent].present?
      return if params[:discount_basis_points].blank?

      Integer(params[:discount_basis_points])
    rescue ArgumentError, TypeError
      raise Pos::Error, "discount must be between 1 and 10000 basis points"
    end

    def expected_lock_version
      params.require(:lock_version)
    end

    def find_line!
      @transaction.pos_transaction_lines.find(params.require(:line_id))
    end

    def default_selected_line
      id = params[:selected_line_id].presence
      (id && @transaction.pos_transaction_lines.find_by(id: id)) || @transaction.pos_transaction_lines.last
    end

    def default_selected_tender
      id = params[:selected_tender_id].presence
      (id && @tenders.find { |tender| tender.id == id }) || @tenders.first
    end

    def previous_line(line)
      lines = @transaction.pos_transaction_lines.to_a
      index = lines.index { |item| item.id == line.id }
      return if index.nil? || index.zero?

      lines[index - 1]
    end

    def apply_post_tender_view!
      if Pos::Support.exact_settlement?(@transaction)
        mint_or_restore_completion!
        @ui_mode = "completion_pending"
      else
        @ui_mode = "tender"
        @auto_complete = false
      end
    end

    def selected_tender_type_from_params
      id = params[:tender_type_id].presence
      selectable = if Pos::Support.settlement_direction(@transaction) == :refund
        TenderType.refund_selectable
      else
        TenderType.cashier_selectable
      end
      return Pos::Support.cash_tender_type if id.blank?

      selectable.find_by(id: id) || raise(Pos::Error, "tender is not available")
    end

    def resolve_selected_tender_type
      id = params[:tender_type_id].presence
      (@cashier_tender_types.find { |type| type.id.to_s == id.to_s }) ||
        @cashier_tender_types.find(&:cash?) ||
        @cashier_tender_types.first
    end

    def pos_workspace_cash_payment?(tender)
      tender.cash? && tender.direction == "payment"
    end

    def find_optional_gift_card_program
      id = params[:gift_card_program_id].presence
      return if id.blank?

      GiftCardProgram.find_by(id: id)
    end

    def stored_value_destination_mode(type)
      explicit = params[:destination_mode].presence
      return explicit if explicit.present?
      return "new_gift_card" if type.code == "gift_card" && params[:card_number].blank?
      return "customer_store_credit" if type.code == "store_credit"

      "existing_account"
    end

    def find_optional_variant
      id = params[:product_variant_id].presence
      return if id.blank?

      ProductVariant.find_by(id: id)
    end

    def find_optional_unit
      id = params[:inventory_unit_id].presence
      return if id.blank?

      InventoryUnit.find_by(id: id)
    end

    def find_optional_product
      id = params[:product_id].presence
      return if id.blank?

      Product.find_by(id: id)
    end

    def parse_optional_open_price
      return if params[:selling_price].blank? && params[:open_price].blank?

      Money::ParseCents.call(params[:selling_price].presence || params[:open_price])
    end

    def serialize_resolution(result)
      payload = { outcome: result.outcome.to_s, message: result.message }
      payload[:variant] = serialize_variant(result.variant) if result.variant
      payload[:unit] = serialize_unit(result.unit) if result.unit
      payload[:variants] = Array(result.variants).map { |variant| serialize_variant(variant) }
      payload[:units] = Array(result.units).map { |unit| serialize_unit(unit) }
      payload[:products] = Array(result.products).map { |product| serialize_product(product) }
      if result.outcome == :gift_card
        payload[:found] = result.gift_card.present?
        payload[:gift_card_id] = result.gift_card&.id
        payload[:masked_number] = result.gift_card&.masked_number
        payload[:status] = result.gift_card&.status
        payload[:balance_cents] = result.gift_card&.balance_cents
        payload[:program_id] = result.gift_card_program&.id
        payload[:program_code] = result.gift_card_program&.code
        payload[:number_authority] = result.gift_card_program&.number_authority
        payload[:reload_allowed] = result.gift_card_program&.reload_allowed
      end
      payload
    end

    def serialize_unlinked_resolution(result)
      payload = {
        outcome: result.outcome.to_s,
        message: result.message
      }
      payload[:variant] = serialize_variant(result.variant) if result.variant
      payload[:unit] = serialize_unit(result.inventory_unit) if result.inventory_unit
      payload[:variants] = Array(result.variants).map { |variant| serialize_variant(variant) }
      payload[:units] = Array(result.units).map { |unit| serialize_unit(unit) }
      payload[:products] = Array(result.products).map { |product| serialize_product(product) }
      if result.outcome == :resolved
        payload.merge!(
          description: result.description,
          tracking: result.tracking,
          quantity_fixed: result.quantity_fixed,
          reference_unit_price_cents: result.reference_unit_price_cents,
          product_variant_id: result.variant.id,
          inventory_unit_id: result.inventory_unit&.id,
          tax_class_id: result.tax_class.id
        )
      end
      payload[:error] = result.message if result.outcome == :unavailable
      payload
    end

    def serialize_product(product)
      {
        id: product.id,
        name: product.name,
        subtitle: product.subtitle,
        brand_name: product.brand_name,
        primary_identifier: product.primary_identifier,
        industry_identifier: product.industry_identifier,
        lookup_code: product.lookup_code
      }
    end

    def serialize_variant(variant)
      tracking = variant.derived_inventory_tracking
      open_price = variant.pricing_method == "open_price"
      {
        id: variant.id,
        sku: variant.sku,
        name: variant.product.name,
        condition: variant.merchandise_condition&.name,
        price_cents: variant.regular_price_cents,
        price_label: open_price ? "Open price" : nil,
        tracking: tracking,
        open_price: open_price,
        available: tracking == "non_inventory" ? nil : Inventory::Availability.available(current_store, variant)
      }
    end

    def serialize_unit(unit)
      {
        id: unit.id,
        unit_identifier: unit.unit_identifier,
        condition: unit.product_variant.merchandise_condition&.name,
        price_cents: unit.effective_regular_price_cents
      }
    end

    def serialize_linked_return(result)
      {
        outcome: result.outcome.to_s,
        message: result.message,
        truncated: result.truncated,
        transaction_id: result.transaction_id,
        receipts: Array(result.receipts).map do |receipt|
          {
            id: receipt.id,
            transaction_reference: receipt.transaction_reference,
            completed_at: receipt.completed_at
          }
        end,
        lines: Array(result.lines).map do |line|
          {
            id: line.id,
            description: line.description,
            remaining: line.remaining,
            sold: line.sold,
            quantity_fixed: line.quantity_fixed,
            unit_identifier: line.unit_identifier
          }
        end
      }
    end

    def serialize_search_row(row)
      {
        id: row.variant.id,
        sku: row.sku,
        name: row.product_name,
        condition: row.condition_name,
        price_label: row.price_label,
        available: row.available,
        disabled: row.disabled,
        reason: row.reason,
        tracking: row.tracking,
        open_price: row.open_price
      }
    end
  end
end
