# frozen_string_literal: true

module Pos
  class ClosedSessionsController < BaseController
    def show
      session_record = PosSession.find_by(id: params[:id], store_id: current_store.id)
      raise ActiveRecord::RecordNotFound unless session_record

      if session_record.open?
        redirect_to pos_session_close_path(session_record)
        return
      end

      redirect_to pos_session_details_path(session_record), status: :moved_permanently
    end
  end
end
