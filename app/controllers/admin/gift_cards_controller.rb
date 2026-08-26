# frozen_string_literal: true

module Admin
  class GiftCardsController < BaseController
    before_action -> { require_permission!("gift_cards.view") }, only: %i[index show inquiry resolve_inquiry print_recovery create_print_recovery]
    before_action -> { require_permission!("gift_cards.suspend") }, only: %i[suspend reinstate]
    before_action -> { require_permission!("gift_cards.replace") }, only: %i[replace create_replacement]
    before_action -> { require_permission!("gift_cards.associate_customer") }, only: %i[associate update_association]
    before_action :set_gift_card, only: %i[show suspend reinstate replace create_replacement associate update_association print_recovery create_print_recovery]

    def index
      @gift_cards = GiftCard.includes(:gift_card_program, :stored_value_account, :customer).admin_ordered.limit(100)
    end

    def show; end

    def inquiry; end

    def resolve_inquiry
      card = GiftCards::Resolver.call(raw_number: params[:card_number], actor: current_user, store: current_store)
      Audit::Recorder.record!(
        action: "gift_cards.inquiry",
        outcome: "succeeded",
        actor_user: current_user,
        store: current_store,
        subject: card,
        after_values: { number_last_four: card.number_last_four, status: card.status }
      )
      redirect_to admin_gift_card_path(card)
    rescue GiftCards::Error => e
      flash.now[:alert] = e.message
      render :inquiry, status: :unprocessable_entity
    end

    def suspend
      GiftCards::Suspend.call(
        gift_card: @gift_card,
        actor: current_user,
        store: operational_store,
        expected_lock_version: params[:lock_version]
      )
      redirect_to admin_gift_card_path(@gift_card), notice: "Gift card suspended."
    rescue GiftCards::Error, ActiveRecord::StaleObjectError => e
      redirect_to admin_gift_card_path(@gift_card), alert: e.message
    end

    def reinstate
      GiftCards::Reinstate.call(
        gift_card: @gift_card,
        actor: current_user,
        store: operational_store,
        expected_lock_version: params[:lock_version]
      )
      redirect_to admin_gift_card_path(@gift_card), notice: "Gift card reinstated."
    rescue GiftCards::Error, ActiveRecord::StaleObjectError => e
      redirect_to admin_gift_card_path(@gift_card), alert: e.message
    end

    def replace; end

    def create_replacement
      replacement = GiftCards::Replace.call(
        gift_card: @gift_card,
        performed_by: current_user,
        store: operational_store!,
        source_id: @gift_card.id,
        idempotency_key: params[:idempotency_key].presence || SecureRandom.uuid_v7,
        reason_code: params[:reason_code],
        reason_name_snapshot: params[:reason_name].presence || params[:reason_code],
        number: params[:card_number],
        notes: params[:notes]
      )
      redirect_to admin_gift_card_path(replacement.replacement_gift_card), notice: "Gift card replaced."
    rescue GiftCards::Error, StoredValue::Error => e
      flash.now[:alert] = e.message
      render :replace, status: :unprocessable_entity
    end

    def associate
      @customer = @gift_card.customer
    end

    def print_recovery; end

    def create_print_recovery
      @recovered_number = GiftCards::PrintRecovery.call(
        gift_card: @gift_card,
        actor: current_user,
        store: operational_store,
        reason: params[:reason]
      )
      render :print_recovery
    rescue GiftCards::Error => e
      flash.now[:alert] = e.message
      render :print_recovery, status: :unprocessable_entity
    end

    def update_association
      customer = params[:customer_id].present? ? Customer.find(params[:customer_id]) : nil
      GiftCards::AssociateCustomer.call(
        gift_card: @gift_card,
        actor: current_user,
        customer: customer,
        store: operational_store,
        expected_lock_version: params[:lock_version]
      )
      redirect_to admin_gift_card_path(@gift_card), notice: "Customer association updated."
    rescue GiftCards::Error, ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError => e
      flash.now[:alert] = e.message
      render :associate, status: :unprocessable_entity
    end

    private

    def set_gift_card
      @gift_card = GiftCard.find(params[:id])
    end

    def operational_store
      current_store || Store.active.order(:name).first
    end

    def operational_store!
      operational_store || raise(GiftCards::Error, "a store is required")
    end
  end
end
