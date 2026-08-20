# frozen_string_literal: true

module Pos
  class ActiveSessionsController < BaseController
    def index
      raise ActiveRecord::RecordNotFound unless can_view_other_sessions?

      @sessions = PosSession.open
                            .where(store: current_store)
                            .includes(:register, :cashier_user, :reporting_period)
                            .joins(:register)
                            .order("registers.register_number", "pos_sessions.opened_at")
    end
  end
end
