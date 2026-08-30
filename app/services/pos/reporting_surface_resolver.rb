# frozen_string_literal: true

module Pos
  # Resolves reporting surfaces (X / closed session / Z) without silent ID fallback.
  # Session-scoped access reuses InquirySessionResolver ownership law.
  class ReportingSurfaceResolver
    Result = Data.define(
      :status,
      :session,
      :period,
      :candidate_sessions,
      :candidate_periods,
      :denied_reason
    )

    RECENT_PERIOD_LIMIT = 20

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(store:, actor:, state:, session_id: nil, reporting_period_id: nil, register_id_param: nil)
      @store = store
      @actor = actor
      @state = state
      @session_id = session_id.to_s.presence
      @reporting_period_id = reporting_period_id.to_s.presence
      @register_id_param = register_id_param.to_s.presence
    end

    def call
      return deny("register_required") if @state.kind == "selector" || @state.register.blank?

      if @reporting_period_id.present?
        resolve_explicit_period
      elsif @session_id.present?
        resolve_explicit_session
      else
        resolve_default
      end
    end

    private

    def resolve_default
      case @state.kind
      when "own_session", "occupied"
        session = @state.gate&.session
        return deny("not_found") if session.blank?
        return deny("sessions_view_required") if @state.kind == "occupied" && !can_view_other_sessions?

        accept_session(session)
      when "between_sessions"
        period = @state.gate&.period
        return chooser_periods(recent_finalized_for_register) if period.blank?

        accept_period(period)
      when "closed"
        chooser_periods(recent_finalized_for_register)
      else
        deny("register_required")
      end
    end

    def resolve_explicit_session
      inquiry = InquirySessionResolver.call(
        store: @store,
        actor: @actor,
        state: @state,
        session_id: @session_id,
        register_id_param: @register_id_param
      )
      case inquiry.status
      when :ok
        accept_session(inquiry.session)
      when :chooser
        Result.new(
          status: :chooser,
          session: nil,
          period: nil,
          candidate_sessions: inquiry.candidate_sessions,
          candidate_periods: [],
          denied_reason: nil
        )
      else
        deny(inquiry.denied_reason || "not_found")
      end
    end

    def resolve_explicit_period
      period = PosReportingPeriod.find_by(id: @reporting_period_id, store_id: @store.id)
      return deny("not_found") unless period
      if @register_id_param.present? && period.register_id.to_s != @register_id_param
        return deny("not_found")
      end
      if @state.register.present? && period.register_id != @state.register.id
        return deny("not_found")
      end

      accept_period(period)
    end

    def accept_session(session)
      Result.new(
        status: :ok,
        session: session,
        period: session.reporting_period,
        candidate_sessions: [],
        candidate_periods: [],
        denied_reason: nil
      )
    end

    def accept_period(period)
      Result.new(
        status: :ok,
        session: nil,
        period: period,
        candidate_sessions: [],
        candidate_periods: [],
        denied_reason: nil
      )
    end

    def chooser_periods(periods)
      Result.new(
        status: :chooser,
        session: nil,
        period: nil,
        candidate_sessions: [],
        candidate_periods: periods,
        denied_reason: nil
      )
    end

    def deny(reason)
      Result.new(
        status: :denied,
        session: nil,
        period: nil,
        candidate_sessions: [],
        candidate_periods: [],
        denied_reason: reason
      )
    end

    def recent_finalized_for_register
      PosReportingPeriod.where(store_id: @store.id, register_id: @state.register.id, status: "finalized")
                        .order(closed_at: :desc, id: :desc)
                        .limit(RECENT_PERIOD_LIMIT)
                        .to_a
    end

    def can_view_other_sessions?
      Authorization::PermissionEvaluator.allowed?(
        user: @actor,
        permission_key: "pos.sessions.view",
        store: @store
      )
    end
  end
end
