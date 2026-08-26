# frozen_string_literal: true

module Cash
  class AvailableCash
    def self.cents(session)
      Pos::SessionTotals.for(session).available_cash_cents
    end

    def self.assert!(session, outgoing_cents)
      needed = Integer(outgoing_cents)
      return if needed <= 0
      return if cents(session) >= needed

      raise Error, INSUFFICIENT_AVAILABLE_CASH
    end
  end
end
