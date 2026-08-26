# frozen_string_literal: true

module Cash
  class SnapshotCount
    STALE = "This count is stale because safe cash changed. Start a new count."

    def self.start!(location:, purpose:)
      raise Error, "safe is not initialized" if location.safe? && !location.initialized?

      locked = CashLocation.lock.find(location.id)
      raise Error, "safe is not initialized" if locked.safe? && !locked.initialized?

      CashCount.create!(
        purpose: purpose,
        total_cents: 0,
        expected_cents_snapshot: locked.expected_balance_cents,
        location_lock_version_snapshot: locked.lock_version,
        cash_location: locked,
        status: "discarded",
        business_date: BusinessDate.for_store(locked.store)
      )
    end

    def self.assert_current!(location, count)
      if location.lock_version != count.location_lock_version_snapshot ||
         location.expected_balance_cents != count.expected_cents_snapshot
        raise Error, STALE
      end
    end

    def self.accept!(count:, total_cents:)
      CashCount.create!(
        purpose: count.purpose,
        total_cents: total_cents,
        expected_cents_snapshot: count.expected_cents_snapshot,
        location_lock_version_snapshot: count.location_lock_version_snapshot,
        cash_location: count.cash_location,
        status: "accepted",
        business_date: count.business_date,
        superseded_count: count
      )
    end
  end
end
