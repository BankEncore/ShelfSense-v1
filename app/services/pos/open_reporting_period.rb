# frozen_string_literal: true

module Pos
  class OpenReportingPeriod
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(store:, register:, actor:, business_date: nil)
      @store = store
      @register = register
      @actor = actor
      @business_date = business_date
    end

    def call
      Pos::Support.authorize!(@actor, @store)
      raise Pos::Error, "register does not belong to store" unless @register.store_id == @store.id
      Pos::Support.require_active_context!(@store, @register)
      calculated_date = BusinessDate.for_store(@store, at: opened_at)
      if supplied_business_date && supplied_business_date != calculated_date
        raise Pos::Error, "business date must match the store calendar date"
      end

      PosReportingPeriod.create!(
        store: @store,
        register: @register,
        status: "open",
        opened_at: opened_at,
        business_date: calculated_date
      )
    rescue ActiveRecord::RecordNotUnique
      raise Pos::Error, "register already has an open reporting period"
    end

    private

    def supplied_business_date
      return if @business_date.blank?

      @business_date.to_date
    rescue ArgumentError, TypeError
      raise Pos::Error, "business date must match the store calendar date"
    end

    def opened_at
      @opened_at ||= Time.current
    end
  end
end
