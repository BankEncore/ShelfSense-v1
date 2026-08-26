# frozen_string_literal: true

module Admin
  class StoredValueAdjustmentReasonsController < BaseController
    before_action -> { require_permission!("stored_value.manage_adjustment_reasons") }
    before_action :set_reason, only: %i[show edit update destroy reactivate]

    def index
      @reasons = StoredValueAdjustmentReason.admin_ordered
    end

    def show; end

    def new
      @reason = StoredValueAdjustmentReason.new(allowed_direction: "either", allowed_account_types: %w[store_credit trade_credit])
    end

    def create
      @reason = StoredValueAdjustmentReason.new(reason_params)
      if create_and_audit!(@reason, action: "stored_value.adjustment_reasons.create", after_values: { code: @reason.code })
        redirect_to admin_stored_value_adjustment_reason_path(@reason), notice: "Adjustment reason created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      rescue_stale do
        if save_and_audit!(
          @reason,
          attrs: reason_params.except(:code),
          action: "stored_value.adjustment_reasons.update",
          before_keys: %w[name description allowed_direction notes_required approval_required]
        )
          redirect_to admin_stored_value_adjustment_reason_path(@reason), notice: "Adjustment reason updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end
    end

    def destroy
      mutate_and_audit!(@reason, action: "stored_value.adjustment_reasons.deactivate") { @reason.update!(active: false) }
      redirect_to admin_stored_value_adjustment_reasons_path, notice: "Adjustment reason deactivated."
    end

    def reactivate
      reactivate_configuration!(
        @reason,
        permission_key: "stored_value.manage_adjustment_reasons",
        audit_action: "stored_value.adjustment_reasons.reactivate",
        redirect_path: admin_stored_value_adjustment_reason_path(@reason)
      )
    end

    private

    def set_reason
      @reason = StoredValueAdjustmentReason.find(params[:id])
    end

    def reason_params
      permitted = params.require(:stored_value_adjustment_reason).permit(
        :code, :name, :description, :allowed_direction, :notes_required, :approval_required,
        :display_order, :lock_version, allowed_account_types: []
      )
      permitted[:allowed_account_types] = Array(permitted[:allowed_account_types]).compact_blank
      permitted
    end
  end
end
