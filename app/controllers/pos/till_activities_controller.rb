# frozen_string_literal: true

module Pos
  class TillActivitiesController < BaseController
    def index
      prepare_inquiry_shell!(surface: :till_activity)
      resolution = resolve_inquiry_session!
      return if performed?

      if resolution.status == :chooser
        @candidate_sessions = resolution.candidate_sessions
        return
      end

      @session_record = resolution.session
      @activity = Pos::TillActivity.call(session: @session_record, page: params[:page])
      @can_view_expected = can_view_expected_for_session?(@session_record)
      @expected_cash_cents = @can_view_expected ? Pos::SessionTotals.for(@session_record).expected_cash_cents : nil
    end

    private

    def resolve_inquiry_session!
      result = Pos::InquirySessionResolver.call(
        store: current_store,
        actor: current_user,
        state: @state,
        session_id: params[:session_id],
        register_id_param: params[:register_id]
      )
      case result.status
      when :ok, :chooser
        result
      else
        redirect_to pos_path, alert: inquiry_denied_message(result.denied_reason)
        result
      end
    end

    def inquiry_denied_message(reason)
      case reason
      when "sessions_view_required"
        "You are not authorized to view that session."
      when "register_required"
        "Select a Register before viewing till activity."
      else
        "That session was not found."
      end
    end

    def can_view_expected_for_session?(session)
      return false unless session
      return false unless can_view_expected_cash?

      session.cashier_user_id == current_user.id || can_view_other_sessions?
    end
  end
end
