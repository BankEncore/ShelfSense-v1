# frozen_string_literal: true

module Pos
  # Resolves which PosSession a till/session inquiry surface should show.
  # Encodes Slice 6B session-selection law; never silently substitutes inaccessible sessions.
  class InquirySessionResolver
    Result = Data.define(
      :status, :session, :candidate_sessions, :denied_reason
    )

    RECENT_LIMIT = 20

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(store:, actor:, state:, session_id: nil, register_id_param: nil)
      @store = store
      @actor = actor
      @state = state
      @session_id = session_id.to_s.presence
      @register_id_param = register_id_param.to_s.presence
    end

    def call
      return deny("register_required") if @state.kind == "selector" || @state.register.blank?

      if @session_id.present?
        return resolve_explicit_session
      end

      case @state.kind
      when "own_session"
        accept(@state.gate.session)
      when "occupied"
        return deny("sessions_view_required") unless can_view_other_sessions?

        accept(@state.gate.session)
      when "between_sessions"
        resolve_between_sessions
      when "closed"
        resolve_closed_chooser
      else
        deny("register_required")
      end
    end

    private

    def resolve_explicit_session
      session = PosSession.find_by(id: @session_id, store_id: @store.id)
      return deny("not_found") unless session

      if @register_id_param.present? && session.register_id.to_s != @register_id_param
        return deny("not_found")
      end
      if @state.register.present? && session.register_id != @state.register.id
        return deny("not_found")
      end
      return deny("not_found") unless can_view_session?(session)

      accept(session)
    end

    def resolve_between_sessions
      period = @state.gate&.period
      return chooser(recent_closed_for_register) if period.blank?

      session = PosSession.closed
                          .where(store_id: @store.id, register_id: @state.register.id, reporting_period_id: period.id)
                          .order(closed_at: :desc, id: :desc)
                          .first
      return chooser(recent_closed_for_register) if session.blank?
      return deny("not_found") unless can_view_session?(session)

      accept(session)
    end

    def resolve_closed_chooser
      chooser(recent_closed_for_register)
    end

    def recent_closed_for_register
      PosSession.closed
                .where(store_id: @store.id, register_id: @state.register.id)
                .includes(:cashier_user, :reporting_period, :register)
                .order(closed_at: :desc, id: :desc)
                .limit(RECENT_LIMIT)
                .select { |session| can_view_session?(session) }
    end

    def can_view_session?(session)
      return false if session.blank?
      return true if session.cashier_user_id == @actor.id
      return true if can_view_other_sessions?

      false
    end

    def can_view_other_sessions?
      Authorization::PermissionEvaluator.allowed?(
        user: @actor,
        permission_key: "pos.sessions.view",
        store: @store
      )
    end

    def accept(session)
      return deny("not_found") if session.blank?

      Result.new(status: :ok, session: session, candidate_sessions: [], denied_reason: nil)
    end

    def chooser(candidates)
      Result.new(status: :chooser, session: nil, candidate_sessions: candidates, denied_reason: nil)
    end

    def deny(reason)
      Result.new(status: :denied, session: nil, candidate_sessions: [], denied_reason: reason)
    end
  end
end
