# frozen_string_literal: true

module Pos
  class PostVoidsController < BaseController
    before_action :load_source_transaction!

    def show
      prepare_post_void_view
    end

    def create
      target_session = cashier_target_session
      unless target_session
        @error = "Open a register before processing a post-void."
        prepare_post_void_view
        render :show, status: :unprocessable_entity
        return
      end

      result = Pos::PostVoidTransaction.call(
        source: @transaction,
        actor: current_user,
        session: target_session,
        operation_id: params.require(:operation_id),
        reversal_transaction_id: params.require(:reversal_transaction_id),
        reason_code: params[:reason_code],
        reason_note: params[:reason_note],
        card_reversals: card_reversals_params,
        approver_username: params[:approver_username],
        approver_password: params[:approver_password]
      )
      session[:pos_register_id] = target_session.register_id
      redirect_to pos_completed_transaction_path(result.transaction)
    rescue Pos::Denied => e
      @error = e.message
      prepare_post_void_view
      render :show, status: :unprocessable_entity
    rescue Pos::PayloadMismatch
      @error = "This post-void request does not match the original request. Reload and try again."
      prepare_post_void_view
      render :show, status: :unprocessable_entity
    rescue Pos::Error => e
      @error = e.message
      prepare_post_void_view
      render :show, status: :unprocessable_entity
    end

    private

    def load_source_transaction!
      @transaction = PosTransaction.completed.find_by!(id: params[:transaction_id], store_id: current_store.id)
    end

    def prepare_post_void_view
      @target_session = cashier_target_session
      @working_transaction = @target_session&.pos_transactions&.working&.first
      @blocking_working = @working_transaction.present? &&
                          (@working_transaction.pos_transaction_lines.exists? || @working_transaction.pos_tenders.exists?)
      @eligible = Pos::PostVoidEligibility.eligible?(@transaction)
      @policy = Pos::ControlledActionPolicy.result(user: current_user, store: current_store, action_type: "post_void")
      @reasons = Pos::PostVoidReasons::ENTRIES
      @card_tenders = @transaction.pos_tenders.select { |tender| tender.behavioral_category == "card" }
      @operation_id = params[:operation_id].presence || SecureRandom.uuid_v7
      @reversal_transaction_id = params[:reversal_transaction_id].presence || SecureRandom.uuid_v7
      @reason_code = params[:reason_code].to_s
      @reason_note = params[:reason_note].to_s
    end

    def card_reversals_params
      rows = params[:card_reversals]
      return [] if rows.blank?

      rows = rows.to_unsafe_h if rows.respond_to?(:to_unsafe_h)
      rows = rows.values if rows.respond_to?(:values)
      rows
    end
  end
end
