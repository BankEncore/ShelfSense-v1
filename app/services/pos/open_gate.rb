# frozen_string_literal: true

module Pos
  class OpenGate
    def self.for(store:, register:, actor:)
      new(store: store, register: register, actor: actor)
    end

    def initialize(store:, register:, actor:)
      @store = store
      @register = register
      @actor = actor
    end

    def session
      @session ||= PosSession.open.find_by(register: @register)
    end

    def period
      @period ||= session&.reporting_period || PosReportingPeriod.open.find_by(register: @register)
    end

    def occupied?
      session.present? && session.cashier_user_id != @actor.id
    end

    def occupier
      session&.cashier_user
    end

    def own_session?
      session.present? && session.cashier_user_id == @actor.id
    end

    def needs_opening_float?
      session.nil?
    end

    def business_date
      period&.business_date || BusinessDate.for_store(@store)
    end

    def leftover_period?
      period.present? && period.business_date != BusinessDate.for_store(@store)
    end

    def enterable?
      !occupied?
    end
  end
end
