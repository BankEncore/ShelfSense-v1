# frozen_string_literal: true

module Pos
  class WorkspacesController < BaseController
    before_action :require_register!
    before_action :prepare_workspace!, except: %i[show continue]
    before_action :prepare_session!, only: :continue

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
    end

    def merchandise
      rescue_workspace do
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
      rescue_workspace do
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
      rescue_workspace do
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

    def abandon_tender
      rescue_workspace do
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
      rescue_workspace do
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
      rescue_workspace do
        presented = Money::ParseCents.call(params[:amount_presented])
        raise Pos::Error, "cash presented is required" if presented.nil?

        Pos::TenderCash.call(
          transaction: @transaction,
          actor: current_user,
          expected_lock_version: expected_lock_version,
          amount_presented_cents: presented
        )
        @transaction.reload
        mint_or_restore_completion!
        @ui_mode = "completion_pending"
        @auto_complete = @completion_status == "pending"
        respond_workspace
      end
    end

    def complete
      rescue_workspace do
        @transaction.reload
        if @transaction.completed?
          redirect_to pos_completed_transaction_path(@transaction)
          return
        end

        result = Pos::CompleteTransaction.call(
          transaction: @transaction,
          actor: current_user,
          operation_id: params.require(:completion_operation_id),
          expected_lock_version: expected_lock_version,
          expected_total_cents: params.require(:expected_total_cents),
          amount_presented_cents: params.require(:amount_presented_cents)
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

    def prepare_view_state
      @period = @session_record.reporting_period
      @lines = @transaction.pos_transaction_lines.includes(product_variant: :product)
      @tender = @transaction.pos_tenders.find_by(tender_type: "cash")
      @selected_line ||= default_selected_line
      @feedback ||= nil
      @command_value ||= nil
      if @tender
        mint_or_restore_completion!
        @ui_mode ||= @completion_status == "failed" ? "completion_failed" : "completion_pending"
        @auto_complete = @completion_status == "pending" || @completion_status == "in_flight"
      else
        @ui_mode ||= "sale_entry"
        @auto_complete = false
      end
    end

    def mint_or_restore_completion!
      found = Pos::FindCompletionOperation.call(transaction: @transaction, actor: current_user)
      if found
        @completion_operation_id = found.id
        @completion_status = found.status
      else
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

    def rescue_workspace
      yield
    rescue Pos::Denied
      redirect_to root_path, alert: "You are not authorized to perform that action."
    rescue Pos::StaleObject
      @feedback = "This sale was changed. Reload and try again."
      @transaction.reload
      @ui_mode = "sale_entry"
      respond_workspace
    rescue Money::ParseCents::Error, Pos::Error => e
      @feedback = e.message
      @transaction.reload
      @command_value = params[:identifier] || params[:quantity] || params[:amount_presented]
      @ui_mode = e.message.match?(/less than amount due|cash presented/i) ? "tender" : workspace_mode_after_error
      if @transaction.completed?
        redirect_to pos_completed_transaction_path(@transaction)
      else
        respond_workspace
      end
    end

    def workspace_mode_after_error
      return "completion_failed" if @transaction.pos_tenders.exists?

      "sale_entry"
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
  end
end
