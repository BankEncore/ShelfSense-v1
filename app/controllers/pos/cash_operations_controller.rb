# frozen_string_literal: true

module Pos
  class CashOperationsController < BaseController
    def show
      prepare_inquiry_shell!(surface: :cash_operation_detail)
      @operation = find_authorized_operation!
      return if performed?

      @session_record = session_for_operation(@operation)
      @session_effect_cents = session_effect_cents(@operation, @session_record)
      @can_reverse = can_reverse?(@operation)
      Cash::ActivityReasons.seed!
      @reasons = CashActivityReason.active.where(operation_kind: "reverse").order(:name)
    end

    def reversal
      prepare_inquiry_shell!(surface: :cash_operation_detail)
      @operation = find_authorized_operation!
      return if performed?

      unless can_reverse?(@operation)
        redirect_to pos_cash_operation_path(@operation, inquiry_register_params),
                    alert: "That cash operation cannot be reversed."
        return
      end

      Cash::Reverse.call(
        operation: @operation,
        actor: current_user,
        reason_code: params[:reason_code],
        notes: params[:notes],
        source_id: params[:source_id].presence || SecureRandom.uuid_v7,
        idempotency_key: params[:idempotency_key].presence || SecureRandom.uuid_v7
      )
      redirect_to pos_cash_operation_path(@operation, inquiry_register_params),
                  notice: "Cash operation reversed."
    rescue Cash::Error => e
      @session_record = session_for_operation(@operation)
      @session_effect_cents = session_effect_cents(@operation, @session_record)
      @can_reverse = can_reverse?(@operation)
      Cash::ActivityReasons.seed!
      @reasons = CashActivityReason.active.where(operation_kind: "reverse").order(:name)
      @error = e.message
      render :show, status: :unprocessable_content
    end

    private

    def find_authorized_operation!
      operation = CashOperation.includes(
        :performed_by, :approved_by, :cash_transfer, :reversed_by, :reversal_of,
        :cash_paid_in, :cash_paid_out, cash_entries: :pos_session
      ).find_by(id: params[:id], store_id: current_store.id)
      unless operation
        redirect_to pos_path, alert: "That cash operation was not found."
        return
      end

      session_record = session_for_operation(operation)
      unless session_record && can_view_session?(session_record)
        redirect_to pos_path, alert: "You are not authorized to view that cash operation."
        return
      end

      operation
    end

    def session_for_operation(operation)
      return operation.pos_session if operation.pos_session_id.present?

      entry = operation.cash_entries.find { |row| row.pos_session_id.present? }
      entry&.pos_session
    end

    def session_effect_cents(operation, session_record)
      return 0 unless session_record

      operation.cash_entries.select { |entry| entry.pos_session_id == session_record.id }.sum(&:amount_cents)
    end

    def can_view_session?(session_record)
      return true if session_record.cashier_user_id == current_user.id
      return true if can_view_other_sessions?

      false
    end

    def can_reverse?(operation)
      return false unless Authorization::PermissionEvaluator.allowed?(
        user: current_user,
        permission_key: "cash.reverse",
        store: current_store
      )

      Cash::Reverse.reversible?(operation)
    end
  end
end
