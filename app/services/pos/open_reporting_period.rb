# frozen_string_literal: true

module Pos
  class OpenReportingPeriod
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(store:, register:, actor:, business_date: nil, opened_at: Time.current)
      @store = store
      @register = register
      @actor = actor
      @business_date = business_date
      @opened_at = opened_at
    end

    def call
      Pos::Support.authorize!(@actor, @store)
      raise Pos::Error, "register does not belong to store" unless @register.store_id == @store.id
      Pos::Support.require_active_context!(@store, @register)

      PosReportingPeriod.create!(
        store: @store,
        register: @register,
        status: "open",
        opened_at: @opened_at,
        business_date: @business_date || BusinessDate.for_store(@store, at: @opened_at)
      )
    rescue ActiveRecord::RecordNotUnique
      raise Pos::Error, "register already has an open reporting period"
    end
  end
end
