# frozen_string_literal: true

module Pos
  class CashOutsController < BaseController
    before_action :require_cash_out_permission!
    before_action :load_cash_out!, only: %i[show reverse]
    before_action :prepare_cash_out_detail_shell!, only: %i[show reverse]
    before_action :prepare_cash_operation_shell!, only: %i[new lookup create]
    before_action :load_open_session!, only: %i[new lookup create]

    def new; end

    def lookup
      @card_number = params[:card_number]
      resolve_card
      @error = "gift card is not available" if @card_number.present? && @gift_card.blank?
      render :new
    end

    def create
      card = GiftCards::Lookup.by_number(params[:card_number])
      raise GiftCards::Error, "gift card is not available" if card.blank?

      cash_out = GiftCards::CashOut.call(
        gift_card: card,
        session: @session_record,
        actor: current_user,
        source_id: params[:source_id].presence || SecureRandom.uuid_v7,
        idempotency_key: params[:idempotency_key].presence || SecureRandom.uuid_v7,
        customer_requested: params[:customer_requested],
        approver_username: params[:approver_username],
        approver_password: params[:approver_password]
      )
      redirect_to pos_cash_out_path(cash_out, register_id: cash_out.register_id, session_id: cash_out.pos_session_id)
    rescue GiftCards::Error, Pos::Denied => e
      @error = e.message
      @card_number = params[:card_number]
      resolve_card
      render :new, status: :unprocessable_entity
    end

    def show
      assign_cash_out_detail!
    end

    def reverse
      assign_cash_out_detail!
      unless @can_reverse
        redirect_to pos_cash_out_path(@cash_out, cash_out_context_params),
                    alert: "Gift-card cash-out can only be reversed on its original open Register session."
        return
      end

      reversal = GiftCards::ReverseCashOut.call(
        cash_out: @cash_out,
        session: @reversal_session,
        actor: current_user,
        source_id: params[:source_id].presence || SecureRandom.uuid_v7,
        idempotency_key: params[:idempotency_key].presence || SecureRandom.uuid_v7,
        physical_cash_returned: params[:physical_cash_returned],
        approver_username: params[:approver_username],
        approver_password: params[:approver_password]
      )
      redirect_to pos_cash_out_path(reversal, register_id: reversal.register_id, session_id: reversal.pos_session_id),
                  notice: "Cash-out reversed. Expected cash includes the returned cash on this session."
    rescue GiftCards::Error, Pos::Denied => e
      assign_cash_out_detail!
      @error = e.message
      render :show, status: :unprocessable_entity
    end

    private

    def prepare_cash_operation_shell!
      prepare_inquiry_shell!(surface: :cash_operation)
    end

    def prepare_cash_out_detail_shell!
      return if performed?

      register = active_registers.find_by(id: params[:register_id]) || @cash_out.register
      if params[:session_id].present? && params[:session_id].to_s != @cash_out.pos_session_id.to_s
        redirect_to pos_path, alert: "That gift-card cash-out was not found."
        return
      end
      if params[:register_id].present? && @cash_out.register_id.to_s != params[:register_id].to_s
        redirect_to pos_path, alert: "That gift-card cash-out was not found."
        return
      end

      prepare_register_shell!(resolve_register_state(requested_register: register))
      @shell_context = Pos::RegisterShellContext.call(
        store: current_store,
        actor: current_user,
        state: @state,
        surface: :cash_operation,
        can_view_expected_cash: can_view_expected_cash?
      )
    end

    def require_cash_out_permission!
      return if Authorization::PermissionEvaluator.allowed?(
        user: current_user,
        permission_key: "gift_cards.cash_out",
        store: current_store
      )

      redirect_to pos_path, alert: "You are not authorized to cash out gift cards."
    end

    def load_open_session!
      @session_record = cashier_target_session
      return if @session_record

      redirect_to pos_path, alert: "Open a register before cashing out a gift card."
    end

    def load_cash_out!
      @cash_out = GiftCardCashOut.includes(:register, :pos_session, gift_card: :gift_card_program)
                                 .find(params[:id])
      raise ActiveRecord::RecordNotFound unless @cash_out.store_id == current_store.id
      unless can_view_cash_out_session?(@cash_out.pos_session)
        redirect_to pos_path, alert: "You are not authorized to view that gift-card cash-out."
      end
    end

    def assign_cash_out_detail!
      @original_session = @cash_out.pos_session
      @reversal_session = cashier_target_session
      @can_reverse = can_reverse_cash_out?
    end

    def can_reverse_cash_out?
      return false if @cash_out.reversal? || @cash_out.reversed?
      return false unless @reversal_session
      return false unless @original_session&.open?
      return false unless @reversal_session.id == @original_session.id
      return false unless @reversal_session.cashier_user_id == current_user.id

      true
    end

    def can_view_cash_out_session?(session_record)
      return false if session_record.blank?
      return true if session_record.cashier_user_id == current_user.id
      return true if can_view_other_sessions?

      false
    end

    def cash_out_context_params
      {
        register_id: @cash_out.register_id,
        session_id: @cash_out.pos_session_id
      }
    end
    helper_method :cash_out_context_params

    def resolve_card
      return if @card_number.blank?

      @gift_card = GiftCards::Lookup.by_number(@card_number)
      @eligibility = GiftCards::CashOutEligibility.call(@gift_card) if @gift_card
    end
  end
end
