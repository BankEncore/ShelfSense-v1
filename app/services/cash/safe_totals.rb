# frozen_string_literal: true

module Cash
  class SafeTotals
    def self.for(location)
      new(location)
    end

    def initialize(location)
      @location = location
    end

    def expected_cents
      @location.expected_balance_cents
    end

    def from_entries_cents
      CashEntry.where(cash_location_id: @location.id).sum(:amount_cents)
    end
  end
end
