# frozen_string_literal: true

module StoredValue
  module AdjustmentReasons
    SEEDS = [
      {
        code: "goodwill",
        name: "Goodwill / accommodation",
        allowed_direction: "credit",
        allowed_account_types: %w[store_credit trade_credit gift_card],
        display_order: 10
      },
      {
        code: "correction_credit",
        name: "Correction (credit)",
        allowed_direction: "credit",
        allowed_account_types: %w[store_credit trade_credit gift_card],
        notes_required: true,
        display_order: 20
      },
      {
        code: "correction_debit",
        name: "Correction (debit)",
        allowed_direction: "debit",
        allowed_account_types: %w[store_credit trade_credit gift_card],
        notes_required: true,
        display_order: 30
      },
      {
        code: "write_off",
        name: "Write-off",
        allowed_direction: "debit",
        allowed_account_types: %w[store_credit trade_credit gift_card],
        notes_required: true,
        approval_required: true,
        display_order: 40
      }
    ].freeze

    def self.seed!
      SEEDS.each do |attrs|
        reason = StoredValueAdjustmentReason.find_or_initialize_by(code: attrs[:code])
        reason.assign_attributes(
          name: attrs[:name],
          allowed_direction: attrs[:allowed_direction],
          allowed_account_types: attrs[:allowed_account_types],
          notes_required: attrs.fetch(:notes_required, false),
          approval_required: attrs.fetch(:approval_required, false),
          display_order: attrs.fetch(:display_order, 0),
          active: true
        )
        reason.save!
      end
    end
  end
end
