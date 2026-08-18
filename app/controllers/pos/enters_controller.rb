# frozen_string_literal: true

module Pos
  class EntersController < BaseController
    def show
      @registers = active_registers
      @register = find_register || (@registers.one? ? @registers.first : nil)
      @gate = Pos::OpenGate.for(store: current_store, register: @register, actor: current_user) if @register
      @opening_float = params[:opening_float]
    end

    def create
      @register = active_registers.find(params.require(:register_id))
      gate = Pos::OpenGate.for(store: current_store, register: @register, actor: current_user)
      if gate.opening_new_period? && params[:confirmed_business_date].blank?
        fail_enter("business date confirmation is required")
        return
      end

      float_cents = parse_opening_float
      result = Pos::EnterRegister.call(
        store: current_store,
        register: @register,
        actor: current_user,
        opening_float_cents: float_cents,
        business_date: params[:confirmed_business_date]
      )
      session[:pos_register_id] = @register.id
      redirect_to pos_register_workspace_path
    rescue ActiveRecord::RecordNotFound
      redirect_to pos_register_enter_path, alert: "Select an active register."
    rescue Money::ParseCents::Error => e
      fail_enter(e.message)
    rescue Pos::Denied
      fail_enter("Register #{@register.admin_label} is open for #{Pos::OpenGate.for(store: current_store, register: @register, actor: current_user).occupier&.display_name}.")
    rescue Pos::Error => e
      fail_enter(e.message)
    end

    private

    def parse_opening_float
      gate = Pos::OpenGate.for(store: current_store, register: @register, actor: current_user)
      return nil unless gate.needs_opening_float?

      parsed = Money::ParseCents.call(params[:opening_float])
      raise Pos::Error, "opening float is required" if parsed.nil?

      parsed
    end

    def fail_enter(message)
      @registers = active_registers
      @gate = @register && Pos::OpenGate.for(store: current_store, register: @register, actor: current_user)
      @opening_float = params[:opening_float]
      flash.now[:alert] = message
      render :show, status: :unprocessable_content
    end
  end
end
