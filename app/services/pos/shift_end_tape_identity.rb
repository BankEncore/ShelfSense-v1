# frozen_string_literal: true

module Pos
  class ShiftEndTapeIdentity
    def self.for_session(session:, store:, generated_at: Time.current, reprint: false)
      period = session.reporting_period
      Pos::ShiftEndTape::Identity.new(
        report_type: session.closed? ? "CLOSED SESSION" : "X REPORT",
        store_label: store.admin_label,
        register_label: session.register.admin_label,
        business_date: period.business_date.iso8601,
        session_reference: "Session #{session.id}",
        cashier_label: session.cashier_user.display_name,
        opened_at_label: format_timestamp(session.opened_at, store),
        closed_at_label: session.closed_at ? format_timestamp(session.closed_at, store) : nil,
        closed_by_label: session.closed_by_user&.display_name,
        generated_at_label: format_timestamp(generated_at, store),
        reprint: reprint
      )
    end

    def self.for_period(period:, store:, generated_at: Time.current, reprint: false)
      Pos::ShiftEndTape::Identity.new(
        report_type: period.finalized? ? "Z REPORT" : "CURRENT Z",
        store_label: store.admin_label,
        register_label: period.register.admin_label,
        business_date: period.business_date.iso8601,
        session_reference: "Period #{period.id}",
        cashier_label: period.finalized_by&.display_name,
        opened_at_label: nil,
        closed_at_label: period.closed_at ? format_timestamp(period.closed_at, store) : nil,
        closed_by_label: period.finalized_by&.display_name,
        generated_at_label: format_timestamp(generated_at, store),
        reprint: reprint
      )
    end

    def self.format_timestamp(time, store)
      return if time.blank?

      zone = ActiveSupport::TimeZone[store.timezone] || ActiveSupport::TimeZone["UTC"]
      time.in_time_zone(zone).strftime("%Y-%m-%d %H:%M")
    end
  end
end
