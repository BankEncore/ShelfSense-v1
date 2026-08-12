# frozen_string_literal: true

module BusinessDate
  # Derives the store-local calendar date for an event instant (ADR-007).
  def self.for_store(store, at: Time.current)
    zone = ActiveSupport::TimeZone[store.timezone] || ActiveSupport::TimeZone["UTC"]
    at.in_time_zone(zone).to_date
  end
end
