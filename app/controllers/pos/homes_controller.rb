# frozen_string_literal: true

module Pos
  class HomesController < BaseController
    def show
      @preferred_register = preferred_register
      @preferred_gate = if @preferred_register
        Pos::OpenGate.for(store: current_store, register: @preferred_register, actor: current_user)
      end
      @open_session = cashier_target_session
    end
  end
end
