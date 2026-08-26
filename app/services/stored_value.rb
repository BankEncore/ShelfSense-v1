# frozen_string_literal: true

module StoredValue
  class Error < StandardError; end

  OUTBOX_EVENT_TYPES = {
    "issue" => "stored_value.issued",
    "activate" => "gift_card.activated",
    "reload" => "stored_value.issued",
    "redeem" => "stored_value.redeemed",
    "refund" => "stored_value.refunded",
    "cash_out" => "stored_value.cash_out_completed",
    "transfer" => "stored_value.transferred",
    "adjust" => "stored_value.adjusted",
    "reverse" => "stored_value.reversed"
  }.freeze
end
