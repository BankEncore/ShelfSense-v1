# frozen_string_literal: true

module Pos
  class PreferredRegistersController < BaseController
    def new
      @registers = active_registers
      @register = preferred_register || find_register || (@registers.one? ? @registers.first : nil)
      @open_session = cashier_target_session
    end

    def create
      @register = active_registers.find(params.require(:register_id))
      write_preferred_register!(@register)
      redirect_to pos_path, notice: "Preferred register is #{@register.admin_label}."
    rescue ActiveRecord::RecordNotFound, ActionController::ParameterMissing
      redirect_to pos_switch_register_path, alert: "Select an active register."
    end
  end
end
