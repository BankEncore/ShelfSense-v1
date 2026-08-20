# frozen_string_literal: true

module Pos
  class EnterRegister
    Result = Struct.new(:session, :transaction, keyword_init: true)

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(store:, register:, actor:, opening_float_cents: nil, business_date: nil)
      @store = store
      @register = register
      @actor = actor
      @opening_float_cents = opening_float_cents
      @business_date = business_date
    end

    def call
      raise Pos::Error, "This Store cannot use POS until its legal name is configured." if @store.legal_name.blank?
      Pos::Support.authorize!(@actor, @store)
      raise Pos::Error, "register does not belong to store" unless @register.store_id == @store.id
      Pos::Support.require_active_context!(@store, @register)

      3.times do
        result = attempt_enter
        return result if result
      end

      raise Pos::Error, "could not enter register"
    end

    private

    def attempt_enter
      session = PosSession.open.find_by(register: @register)
      if session
        Pos::Support.require_session_cashier!(@actor, session)
        return complete(session)
      end

      period = existing_or_open_period
      return if period.nil?

      session = open_session(period)
      return if session.nil?

      complete(session)
    end

    def existing_or_open_period
      existing = PosReportingPeriod.open.find_by(register: @register)
      if existing
        require_matching_confirmed_date!(existing)
        return existing
      end

      Pos::OpenReportingPeriod.call(
        store: @store,
        register: @register,
        actor: @actor,
        business_date: @business_date
      )
    rescue Pos::Error => e
      raise unless e.message.match?(/already has an open reporting period/)

      nil
    end

    def require_matching_confirmed_date!(period)
      return if @business_date.blank?

      confirmed = @business_date.to_date
      return if period.business_date == confirmed

      raise Pos::Error, "this register is already open on business date #{period.business_date.iso8601}"
    rescue ArgumentError, TypeError
      raise Pos::Error, "business date must match the store calendar date"
    end

    def open_session(period)
      Pos::OpenSession.call(
        store: @store,
        register: @register,
        actor: @actor,
        reporting_period: period,
        opening_float_cents: required_opening_float!
      )
    rescue Pos::Error => e
      raise unless e.message.match?(/already has an open session/)

      nil
    end

    def complete(session)
      Result.new(
        session: session,
        transaction: Pos::ResumeOrStartTransaction.call(session: session, actor: @actor)
      )
    end

    def required_opening_float!
      raise Pos::Error, "opening float is required" if @opening_float_cents.nil?

      @opening_float_cents
    end
  end
end
