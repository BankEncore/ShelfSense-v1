# frozen_string_literal: true

module Cash
  module ActivityReasons
    SEEDS = [
      { code: "over_count", name: "Over count", operation_kind: "over" },
      { code: "short_count", name: "Short count", operation_kind: "short" },
      { code: "paid_in_other", name: "Other paid-in", operation_kind: "paid_in", notes_required: true },
      { code: "paid_out_other", name: "Other paid-out", operation_kind: "paid_out", notes_required: true },
      { code: "reverse", name: "Reversal", operation_kind: "reverse", notes_required: true }
    ].freeze

    def self.seed!
      SEEDS.each do |attrs|
        reason = CashActivityReason.find_or_initialize_by(code: attrs[:code])
        reason.assign_attributes(
          name: attrs[:name],
          operation_kind: attrs[:operation_kind],
          notes_required: attrs.fetch(:notes_required, false),
          active: true
        )
        reason.save!
      end
    end

    def self.require!(code, kind)
      reason = CashActivityReason.active.find_by(code: code.to_s)
      raise Error, "cash activity reason is required" if reason.blank?
      raise Error, "cash activity reason is not valid for this operation" unless reason.operation_kind == kind.to_s

      reason
    end
  end
end
