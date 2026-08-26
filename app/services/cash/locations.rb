# frozen_string_literal: true

module Cash
  class Locations
    def self.ensure!(store)
      now = Time.current
      %w[safe deposit_in_transit].each do |type|
        CashLocation.find_or_create_by!(store: store, location_type: type) do |location|
          location.expected_balance_cents = 0
          location.created_at = now
          location.updated_at = now
        end
      end
    end

    def self.safe_for!(store)
      ensure!(store)
      CashLocation.find_by!(store: store, location_type: "safe")
    end

    def self.deposit_in_transit_for!(store)
      ensure!(store)
      CashLocation.find_by!(store: store, location_type: "deposit_in_transit")
    end
  end
end
