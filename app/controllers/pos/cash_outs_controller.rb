# frozen_string_literal: true

module Pos
  class CashOutsController < BaseController
    before_action :require_cash_out_permission!
    before_action :load_open_session!, except: :show
    before_action :load_cash_out!, only: %i[show reverse]

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
      redirect_to pos_cash_out_path(cash_out)
    rescue GiftCards::Error, Pos::Denied => e
      @error = e.message
      @card_number = params[:card_number]
      resolve_card
      render :new, status: :unprocessable_entity
    end

    def show; end

    def reverse
      reversal = GiftCards::ReverseCashOut.call(
        cash_out: @cash_out,
        session: @session_record,
        actor: current_user,
        source_id: params[:source_id].presence || SecureRandom.uuid_v7,
        idempotency_key: params[:idempotency_key].presence || SecureRandom.uuid_v7,
        physical_cash_returned: params[:physical_cash_returned],
        approver_username: params[:approver_username],
        approver_password: params[:approver_password]
      )
      redirect_to pos_cash_out_path(reversal), notice: "Cash-out reversed. Expected cash includes the returned cash on this session."
    rescue GiftCards::Error, Pos::Denied => e
      @error = e.message
      render :show, status: :unprocessable_entity
    end

    private

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
      unless @session_record
        redirect_to pos_register_enter_path, alert: "Open a register before cashing out a gift card."
      end
    end

    def load_cash_out!
      @cash_out = GiftCardCashOut.find(params[:id])
      raise ActiveRecord::RecordNotFound unless @cash_out.store_id == current_store.id
    end

    def resolve_card
      return if @card_number.blank?

      @gift_card = GiftCards::Lookup.by_number(@card_number)
      @eligibility = GiftCards::CashOutEligibility.call(@gift_card) if @gift_card
    end
  end
end
