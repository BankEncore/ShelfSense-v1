# frozen_string_literal: true

module Pos
  class OpenSession
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(store:, register:, actor:, reporting_period: nil, opened_at: Time.current)
      @store = store
      @register = register
      @actor = actor
      @reporting_period = reporting_period
      @opened_at = opened_at
    end

    def call
      Pos::Support.authorize!(@actor, @store)
      period = @reporting_period || PosReportingPeriod.open.find_by!(register: @register)
      raise Pos::Error, "reporting period is not open" unless period.open?
      raise Pos::Error, "reporting period does not belong to this register" unless period.register_id == @register.id

      PosSession.create!(
        store: @store,
        register: @register,
        reporting_period: period,
        cashier_user: @actor,
        status: "open",
        opened_at: @opened_at
      )
    rescue ActiveRecord::RecordNotUnique
      raise Pos::Error, "register already has an open session"
    end
  end
end
