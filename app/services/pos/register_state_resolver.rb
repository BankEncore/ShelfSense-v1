# frozen_string_literal: true

module Pos
  class RegisterStateResolver
    Result = Struct.new(:kind, :register, :gate, :owned_sessions, :reason, keyword_init: true)

    def self.call(...)
      new(...).call
    end

    def initialize(store:, actor:, requested_register:, preferred_register:, bound_register_id:, owned_open_sessions:)
      @store = store
      @actor = actor
      @requested_register = requested_register
      @preferred_register = preferred_register
      @bound_register_id = bound_register_id
      @owned_open_sessions = Array(owned_open_sessions)
    end

    def call
      owned = scoped_owned_sessions
      register, reason = select_register(owned)
      unless register
        return Result.new(kind: "selector", register: nil, gate: nil, owned_sessions: owned, reason: reason)
      end

      gate = Pos::OpenGate.for(store: @store, register: register, actor: @actor)
      Result.new(kind: kind_for(gate), register: register, gate: gate, owned_sessions: owned, reason: reason)
    end

    private

    def scoped_owned_sessions
      @owned_open_sessions
        .select { |session| session.store_id == @store.id && session.cashier_user_id == @actor.id && session.open? }
        .sort_by { |session| session.register.register_number }
    end

    def select_register(owned)
      usable = usable_register(@requested_register)
      return [ usable, "requested" ] if usable

      bound = bound_owned_register(owned)
      return [ bound, "bound" ] if bound

      if owned.one?
        sole = usable_register(owned.first.register)
        return [ sole, "sole_owned" ] if sole
      end

      return [ nil, "multiple_owned" ] if owned.many?

      preferred = usable_register(@preferred_register)
      return [ preferred, "preferred" ] if preferred

      [ nil, "selector" ]
    end

    def bound_owned_register(owned)
      return if @bound_register_id.blank?

      session = owned.find { |item| item.register_id.to_s == @bound_register_id.to_s }
      return unless session

      usable_register(session.register)
    end

    def usable_register(register)
      return if register.blank?
      return unless register.store_id == @store.id
      return unless register.active?

      register
    end

    def kind_for(gate)
      return "occupied" if gate.occupied?
      return "own_session" if gate.own_session?
      return "between_sessions" if gate.period.present?

      "closed"
    end
  end
end
