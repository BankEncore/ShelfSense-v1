# frozen_string_literal: true

module Admin
  class SystemSettingsController < BaseController
    before_action -> { require_permission!("system_settings.view") }, only: :show
    before_action -> { require_permission!("system_settings.manage") }, only: %i[edit update]

    def show
      @settings = SystemSettings.current
    end

    def edit
      @settings = SystemSettings.current
    end

    def update
      rescue_stale do
        @settings = SystemSettings.current
        before = @settings.attributes.slice(
          "organization_name", "legal_name", "default_timezone", "default_country_code",
          "default_receipt_header", "default_receipt_footer",
          "stored_value_adjust_credit_approval_threshold_cents"
        )
        if @settings.update(settings_params)
          Audit::Recorder.record!(
            action: "system_settings.update",
            outcome: "succeeded",
            actor_user: current_user,
            actor_label: current_user.display_name,
            subject: @settings,
            before_values: before,
            after_values: @settings.attributes.slice(*before.keys)
          )
          redirect_to admin_system_settings_path, notice: "Settings updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end
    end

    private

    def settings_params
      params.require(:system_settings).permit(
        :organization_name, :legal_name, :base_currency_code, :default_timezone,
        :default_country_code, :default_region_code, :fiscal_year_start_month,
        :default_supplier_cancellation_days, :default_customer_reservation_expiration_days,
        :default_receipt_header, :default_receipt_footer, :stored_value_adjust_credit_approval_threshold_cents, :lock_version
      )
    end
  end
end
