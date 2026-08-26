# frozen_string_literal: true

module Cash
  class Error < StandardError; end

  INSUFFICIENT_AVAILABLE_CASH = "This register session does not have enough available cash. Replenish it from the safe or choose another permitted payout method."

  OUTBOX_EVENT_TYPES = {
    "initialize_safe" => "cash.safe_initialized",
    "transfer" => "cash.transferred",
    "paid_in" => "cash.paid_in",
    "paid_out" => "cash.paid_out",
    "reconcile" => "cash.reconciled",
    "reverse" => "cash.reversed"
  }.freeze
end
