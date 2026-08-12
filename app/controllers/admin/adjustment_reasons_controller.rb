# frozen_string_literal: true

module Admin
  class AdjustmentReasonsController < BaseController
    before_action -> { require_permission!("inventory.manage_adjustment_reasons") }
    before_action :set_reason, only: %i[show edit update destroy reactivate]

    def index
      @adjustment_reasons = AdjustmentReason.order(:code)
    end

    def show; end

    def new
      @adjustment_reason = AdjustmentReason.new(direction: "either", cost_required_for_increase: true)
    end

    def create
      @adjustment_reason = AdjustmentReason.new(reason_params)
      if create_and_audit!(@adjustment_reason, action: "adjustment_reasons.create", after_values: { code: @adjustment_reason.code })
        redirect_to admin_adjustment_reason_path(@adjustment_reason), notice: "Adjustment reason created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      redirect_to admin_adjustment_reason_path(@adjustment_reason), alert: "System-protected reasons cannot be edited." if @adjustment_reason.system_protected?
    end

    def update
      if @adjustment_reason.system_protected?
        redirect_to admin_adjustment_reason_path(@adjustment_reason), alert: "System-protected reasons cannot be edited."
        return
      end

      rescue_stale do
        if save_and_audit!(
          @adjustment_reason,
          attrs: reason_params.except(:code),
          action: "adjustment_reasons.update",
          before_keys: %w[name description direction cost_required_for_increase notes_required]
        )
          redirect_to admin_adjustment_reason_path(@adjustment_reason), notice: "Adjustment reason updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end
    end

    def destroy
      if @adjustment_reason.system_protected?
        redirect_to admin_adjustment_reason_path(@adjustment_reason), alert: "System-protected reasons cannot be deactivated."
        return
      end

      mutate_and_audit!(@adjustment_reason, action: "adjustment_reasons.deactivate") do
        @adjustment_reason.update!(active: false)
      end
      redirect_to admin_adjustment_reasons_path, notice: "Adjustment reason deactivated."
    end

    def reactivate
      reactivate_configuration!(
        @adjustment_reason,
        permission_key: "inventory.manage_adjustment_reasons",
        audit_action: "adjustment_reasons.reactivate",
        redirect_path: admin_adjustment_reason_path(@adjustment_reason)
      )
    end

    private

    def set_reason
      @adjustment_reason = AdjustmentReason.find(params[:id])
    end

    def reason_params
      params.require(:adjustment_reason).permit(
        :code, :name, :description, :direction, :cost_required_for_increase, :notes_required,
        :allows_quantity_tracking, :allows_individual_tracking, :lock_version
      )
    end
  end
end
