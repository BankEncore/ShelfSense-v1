# frozen_string_literal: true

module Cash
  class SnapshotCount
    STALE = "This count is stale because safe cash changed. Start a new count."
    ALREADY_ACCEPTED = "This count has already been accepted."
    NOT_DISCARDED = "This count is not a discarded snapshot."

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
      locked = CashCount.lock.find(count.id)
      raise Error, NOT_DISCARDED unless locked.status == "discarded"
      raise Error, ALREADY_ACCEPTED if CashCount.exists?(superseded_count_id: locked.id)

      CashCount.create!(
        purpose: locked.purpose,
        total_cents: total_cents,
        expected_cents_snapshot: locked.expected_cents_snapshot,
        location_lock_version_snapshot: locked.location_lock_version_snapshot,
        cash_location: locked.cash_location,
        status: "accepted",
        business_date: locked.business_date,
        superseded_count: locked
      )
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
      raise Error, ALREADY_ACCEPTED if CashCount.exists?(superseded_count_id: count.id)

      raise Error, e.message
    end
  end
end
