# frozen_string_literal: true

module Pos
  # Shared ownership / sessions.view law for reporting surfaces (Slice 6C).
  module ReportAccess
    extend ActiveSupport::Concern

    private

    def can_view_report_session?(session_record)
      return false if session_record.blank?
      return true if session_record.cashier_user_id == current_user.id
      return true if can_view_other_sessions?

      false
    end

    def can_view_report_period?(period)
      return false if period.blank?
      return true if can_view_other_sessions?
      return true if period.finalized_by_user_id == current_user.id
      return true if period.pos_sessions.exists?(cashier_user_id: current_user.id)

      false
    end

    def authorize_report_session!(session_record)
      raise ActiveRecord::RecordNotFound unless can_view_report_session?(session_record)
    end

    def authorize_report_period!(period)
      raise ActiveRecord::RecordNotFound unless can_view_report_period?(period)
    end
  end
end
