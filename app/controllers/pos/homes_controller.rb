# frozen_string_literal: true

module Pos
  class HomesController < BaseController
    def show
      prepare_register_shell!
      return unless @state.kind == "own_session"
      return unless working_transaction_for(@state)

      redirect_to pos_register_workspace_path(register_id: @state.register.id)
    end

    private

    def working_transaction_for(state)
      session_record = state.gate&.session
      return if session_record.blank?

      session_record.pos_transactions.working.first
    end
  end
end
