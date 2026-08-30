# frozen_string_literal: true

module Pos
  class RegisterMenu
    Group = Struct.new(:key, :item_keys, keyword_init: true)
    Result = Struct.new(:groups, keyword_init: true)

    TILL_KEYS = %i[till_activity gift_card_cash_out paid_in paid_out drop replenish].freeze
    SWITCH_SUPPRESSED = (
      TILL_KEYS + %i[switch_register x_report close_session open_register open_session finalize_z session_details]
    ).freeze
    INQUIRY_SUPPRESSED = %i[open_register open_session finalize_z close_session].freeze
    CASH_OPERATION_SUPPRESSED = (
      INQUIRY_SUPPRESSED + %i[gift_card_cash_out paid_in paid_out drop replenish]
    ).freeze

    def self.call(...)
      new(...).call
    end

    def initialize(kind:, surface:, permissions:, gate: nil)
      @kind = kind.to_s
      @surface = surface.to_sym
      @permissions = Array(permissions).map(&:to_s)
      @gate = gate
    end

    def call
      groups = [
        Group.new(key: :customer_service, item_keys: filter(customer_service_keys)),
        Group.new(key: :till, item_keys: filter(till_keys)),
        Group.new(key: :session_and_register, item_keys: filter(session_and_register_keys))
      ]
      Result.new(groups: groups.select { |group| group.item_keys.any? })
    end

    private

    def filter(keys)
      keys.reject { |key| suppressed?(key) }
    end

    def suppressed?(key)
      return true if @surface == :switch_register && SWITCH_SUPPRESSED.include?(key)
      return true if @surface == :inquiry && INQUIRY_SUPPRESSED.include?(key)
      return true if @surface == :cash_operation && CASH_OPERATION_SUPPRESSED.include?(key)

      false
    end

    def customer_service_keys
      %i[transactions stored_value_inquiry customer_summary pickup_queue]
    end

    def till_keys
      return [] unless @kind == "own_session"

      keys = [ :till_activity ]
      keys << :gift_card_cash_out if permitted?("gift_cards.cash_out")
      keys << :paid_in if permitted?("cash.paid_in")
      keys << :paid_out if permitted?("cash.paid_out")
      keys << :drop
      keys << :replenish if permitted?("cash.move")
      keys
    end

    def session_and_register_keys
      keys = []
      keys << :x_report if x_report?
      keys << :session_details if session_details?
      keys << :session_z_reports if session_z_reports?
      keys << :active_sessions if permitted?("pos.sessions.view")
      keys << :switch_register
      keys << :open_register if open_register?
      keys << :open_session if open_session?
      keys << :finalize_z if finalize_z?
      keys << :close_session if @surface == :workspace
      keys << :return_to_shelfsense
      keys
    end

    def session_details?
      return true if @kind == "own_session"
      return false unless @kind == "occupied"
      return false unless permitted?("pos.sessions.view")

      @gate.respond_to?(:session) && @gate.session.present?
    end

    def x_report?
      return true if @kind == "own_session"
      return false unless @kind == "occupied"
      return false unless permitted?("pos.sessions.view")

      @gate.respond_to?(:session) && @gate.session.present?
    end

    def session_z_reports?
      return true if %w[closed between_sessions own_session].include?(@kind)
      return permitted?("pos.sessions.view") if @kind == "occupied"

      true
    end

    def open_register?
      @surface == :state_landing && @kind == "closed"
    end

    def open_session?
      @surface == :state_landing && @kind == "between_sessions"
    end

    def finalize_z?
      @surface == :state_landing && @gate.respond_to?(:can_finalize_period?) && @gate.can_finalize_period?
    end

    def permitted?(key)
      @permissions.include?(key)
    end
  end
end
