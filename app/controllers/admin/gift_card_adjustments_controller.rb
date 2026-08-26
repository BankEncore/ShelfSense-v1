# frozen_string_literal: true

module Admin
  class GiftCardAdjustmentsController < BaseController
    before_action -> { require_permission!("stored_value.adjust") }
    before_action :set_gift_card

    def new
      @account = @gift_card.stored_value_account
      @reasons = StoredValueAdjustmentReason.active.admin_ordered.select { |reason|
        Array(reason.allowed_account_types).include?("gift_card")
      }
    end

    def create
      @account = @gift_card.stored_value_account
      reason = StoredValueAdjustmentReason.find(params.require(:reason_id))
      direction = params.require(:direction)
      amount_cents = Money::ParseCents.call(params[:amount])
      raise StoredValue::Error, "amount is required" if amount_cents.nil?

      approved_by = approver_if_required!(direction: direction, amount_cents: amount_cents, reason: reason)
      StoredValue::Adjust.call(
        account: @account,
        direction: direction,
        amount_cents: amount_cents,
        reason: reason,
        store: operational_store!,
        performed_by: current_user,
        approved_by: approved_by,
        source_id: @account.id,
        idempotency_key: params[:idempotency_key].presence || SecureRandom.uuid_v7,
        internal_notes: params[:internal_notes]
      )
      redirect_to admin_gift_card_path(@gift_card), notice: "Stored-value adjustment posted."
    rescue StoredValue::Error, Money::ParseCents::Error, ArgumentError => e
      @reasons = StoredValueAdjustmentReason.active.admin_ordered.select { |reason|
        Array(reason.allowed_account_types).include?("gift_card")
      }
      flash.now[:alert] = e.message
      render :new, status: :unprocessable_entity
    end

    private

    def set_gift_card
      @gift_card = GiftCard.find(params[:gift_card_id])
    end

    def operational_store!
      current_store || Store.active.order(:name).first || raise(StoredValue::Error, "a store is required")
    end

    def approver_if_required!(direction:, amount_cents:, reason:)
      return unless StoredValue::Adjust.second_user_required?(
        direction: direction,
        amount_cents: amount_cents,
        reason: reason,
        account: @account
      )

      StoredValue::AuthenticateApprover.call(
        username: params[:approver_username],
        password: params[:approver_password],
        performer: current_user,
        permission_key: "stored_value.adjust",
        store: operational_store!
      )
    end
  end
end
