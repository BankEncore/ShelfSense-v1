# frozen_string_literal: true

module Pos
  class OpenSession
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(store:, register:, actor:, opening_float_cents:, reporting_period: nil)
      @store = store
      @register = register
      @actor = actor
      @opening_float_cents = opening_float_cents
      @reporting_period = reporting_period
    end

    def call
      Pos::Support.authorize!(@actor, @store)
      float_cents = Pos::Support.parse_nonnegative_cents!(@opening_float_cents, "opening float")

      PosSession.transaction do
        period = lock_period!
        Pos::Support.require_active_context!(@store, @register)
        raise Pos::Error, "reporting period is not open" unless period.open?
        raise Pos::Error, "reporting period does not belong to this register" unless period.register_id == @register.id
        raise Pos::Error, "reporting period does not belong to this store" unless period.store_id == @store.id

        session = PosSession.create!(
          store: @store,
          register: @register,
          reporting_period: period,
          cashier_user: @actor,
          status: "open",
          opened_at: Time.current,
          opening_float_cents: float_cents
        )
        Audit::Recorder.record!(
          action: "pos.session.opened",
          outcome: "succeeded",
          actor_user: @actor,
          actor_label: @actor.display_name,
          store: @store,
          register: @register,
          subject: session,
          after_values: { opening_float_cents: session.opening_float_cents }
        )
        session
      end
    rescue ActiveRecord::RecordNotUnique
      raise Pos::Error, "register already has an open session"
    end

    private

    def lock_period!
      if @reporting_period
        PosReportingPeriod.lock.find(@reporting_period.id)
      else
        PosReportingPeriod.open.lock.find_by!(register: @register)
      end
    end
  end
end
