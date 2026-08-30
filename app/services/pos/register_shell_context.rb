# frozen_string_literal: true

module Pos
  # Read-only DTO for Register shell inquiry and detail surfaces.
  # Does not create records, read cookies/session, or reimplement RegisterMenu.
  class RegisterShellContext
    Result = Struct.new(
      :surface,
      :kind,
      :register,
      :session,
      :gate,
      :owned_sessions,
      :menu_surface,
      :return_path,
      :return_label,
      :can_view_expected_cash,
      keyword_init: true
    )

    SURFACES = %i[
      transaction_history
      stored_value_inquiry
      customer_summary
      pickup_queue
      till_activity
      session_detail
      active_sessions
      x_report
      z_period
      cash_operation
    ].freeze

    def self.call(...)
      new(...).call
    end

    def initialize(store:, actor:, state:, surface:, can_view_expected_cash:)
      @store = store
      @actor = actor
      @state = state
      @surface = surface.to_sym
      @can_view_expected_cash = !!can_view_expected_cash
    end

    def call
      raise ArgumentError, "unknown Register shell surface: #{@surface}" unless SURFACES.include?(@surface)

      Result.new(
        surface: @surface,
        kind: @state.kind,
        register: @state.register,
        session: session_for(@state),
        gate: @state.gate,
        owned_sessions: Array(@state.owned_sessions),
        menu_surface: :inquiry,
        return_path: return_path_for(@state),
        return_label: return_label_for(@state),
        can_view_expected_cash: @can_view_expected_cash
      )
    end

    private

    def session_for(state)
      return unless state.gate.respond_to?(:session)

      state.gate.session
    end

    def return_path_for(state)
      register = state.register
      case state.kind
      when "own_session"
        return Rails.application.routes.url_helpers.pos_register_workspace_path(register_id: register.id) if register

        Rails.application.routes.url_helpers.pos_path
      when "closed", "between_sessions", "occupied"
        if register
          Rails.application.routes.url_helpers.pos_path(register_id: register.id)
        else
          Rails.application.routes.url_helpers.pos_path
        end
      else
        Rails.application.routes.url_helpers.pos_path
      end
    end

    def return_label_for(state)
      case state.kind
      when "own_session"
        "Return to Register"
      when "occupied"
        "Return to Register"
      when "closed", "between_sessions"
        "Close"
      else
        "Close"
      end
    end
  end
end
