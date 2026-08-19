# frozen_string_literal: true

module Pos
  class WorkspacesController < BaseController
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
        @selected_line = Pos::AddMerchandise.call(
          transaction: @transaction,
          actor: current_user,
          expected_lock_version: expected_lock_version,
          identifier: params.require(:identifier),
          quantity: 1
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
          line: line,
          actor: current_user,
          expected_lock_version: expected_lock_version,
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

    def abandon_tender
      rescue_workspace(error_mode: "derive") do
        Pos::AbandonTender.call(
          transaction: @transaction,
          actor: current_user,
          expected_lock_version: expected_lock_version
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
        if type.cash?
          presented = Money::ParseCents.call(params[:amount_presented])
          raise Pos::Error, "cash presented is required" if presented.nil?

          Pos::TenderCash.call(
            transaction: @transaction,
            actor: current_user,
            expected_lock_version: expected_lock_version,
            amount_presented_cents: presented
          )
        else
          amount = Money::ParseCents.call(params[:amount_presented])
          raise Pos::Error, "tender amount is required" if amount.nil?

          Pos::AddTender.call(
            transaction: @transaction,
            actor: current_user,
            expected_lock_version: expected_lock_version,
            tender_type: type,
            amount_cents: amount,
            external_reference: params[:external_reference]
          )
        end
        @transaction.reload
        apply_post_tender_view!
        respond_workspace
      end
    end

    def remove_tender
      rescue_workspace(error_mode: "tender") do
        tender = @transaction.pos_tenders.find(params.require(:tender_id))
        Pos::RemoveWorkingTender.call(
          transaction: @transaction,
          actor: current_user,
          expected_lock_version: expected_lock_version,
          tender: tender
        )
        @transaction.reload
        @ui_mode = @transaction.pos_tenders.any? ? "tender" : "sale_entry"
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
        result = Pos::CompleteTransaction.call(
          transaction: @transaction,
          actor: current_user,
          operation_id: params.require(:completion_operation_id),
          expected_lock_version: expected_lock_version,
          expected_total_cents: expected_total,
          expected_signed_net_cents: expected_total
        )
        redirect_to pos_completed_transaction_path(result.transaction)
      end
    end

    def continue
      Pos::ResumeOrStartTransaction.call(session: @session_record, actor: current_user)
      redirect_to pos_register_workspace_path
    rescue Pos::Denied, Pos::Error => e
      redirect_to pos_register_enter_path(register_id: @register.id), alert: e.message
    end

    private

    def require_register!
      @register = find_register
      return if @register

      redirect_to pos_register_enter_path
    end

    def actor_session
      PosSession.open.find_by(store: current_store, register: @register, cashier_user: current_user)
    end

    def prepare_session!
      @session_record = actor_session
      return if @session_record

      redirect_to pos_register_enter_path(register_id: @register&.id)
    end

    def prepare_workspace!
      @session_record = actor_session
      unless @session_record
        redirect_to pos_register_enter_path(register_id: @register.id)
        return
      end

      @transaction = @session_record.pos_transactions.working.first
      return if @transaction

      redirect_to pos_register_enter_path(register_id: @register.id)
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
      @period = @session_record.reporting_period
      @lines = @transaction.pos_transaction_lines.includes(:inventory_unit, :pos_controlled_actions, product_variant: [ :product, :merchandise_condition ])
      @tenders = @transaction.pos_tenders.ordered.to_a
      @tender = @tenders.find(&:cash?)
      @remaining_due_cents = Pos::Support.remaining_due_cents(@transaction)
      @cashier_tender_types = TenderType.cashier_selectable.to_a
      @selected_tender_type = resolve_selected_tender_type
      @selected_line ||= default_selected_line
      @tax_classes = TaxClass.active.order(:code)
      @control_policies = {
        "price_override" => Pos::ControlledActionPolicy.result(user: current_user, store: current_store, action_type: "price_override").to_s,
        "line_discount" => Pos::ControlledActionPolicy.result(user: current_user, store: current_store, action_type: "line_discount").to_s,
        "tax_class_override" => Pos::ControlledActionPolicy.result(user: current_user, store: current_store, action_type: "tax_class_override").to_s
      }
      @feedback ||= nil
      @command_value ||= nil
      if Pos::Support.exact_settlement?(@transaction)
        mint_or_restore_completion!
        apply_completion_view_state
      elsif @tenders.any?
        @ui_mode ||= "tender"
        @auto_complete = false
      else
        @ui_mode ||= "sale_entry"
        @auto_complete = false
      end
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
    rescue Pos::Denied
      redirect_to root_path, alert: "You are not authorized to perform that action."
    rescue Pos::StaleObject
      recover_from_workspace_error("This sale was changed. Reload and try again.", error_mode)
    rescue Money::ParseCents::Error, Pos::Error => e
      recover_from_workspace_error(e.message, error_mode)
    end

    def recover_from_workspace_error(message, error_mode)
      @feedback = message
      @transaction.reload
      @command_value = params[:identifier] || params[:quantity] || params[:amount_presented]
      if @transaction.completed?
        redirect_to pos_completed_transaction_path(@transaction)
        return
      end

      apply_error_mode(error_mode)
      respond_workspace
    end

    def apply_error_mode(error_mode)
      return if Pos::Support.exact_settlement?(@transaction)
      return if error_mode == "derive"

      @ui_mode = error_mode
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
      return Pos::Support.cash_tender_type if id.blank?

      TenderType.cashier_selectable.find_by(id: id) || raise(Pos::Error, "tender is not available")
    end

    def resolve_selected_tender_type
      id = params[:tender_type_id].presence
      (@cashier_tender_types.find { |type| type.id.to_s == id.to_s }) ||
        @cashier_tender_types.find(&:cash?) ||
        @cashier_tender_types.first
    end
  end
end
