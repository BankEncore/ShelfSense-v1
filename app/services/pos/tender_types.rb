# frozen_string_literal: true

module Pos
  module TenderTypes
    SEEDS = [
      { code: "cash", name: "Cash", behavioral_category: "cash", external_reference_policy: "omitted", allows_refund: true },
      { code: "card", name: "External Card", behavioral_category: "card", external_reference_policy: "optional", allows_refund: true },
      { code: "check", name: "Check", behavioral_category: "check", external_reference_policy: "optional", allows_refund: false },
      {
        code: "store_credit",
        name: "Store credit",
        behavioral_category: "stored_value",
        stored_value_account_type: "store_credit",
        external_reference_policy: "omitted",
        allows_refund: true,
        allows_original_tender_refund: true,
        allows_generic_refund_destination: true,
        allows_refund_instrument_replacement: false
      },
      {
        code: "trade_credit",
        name: "Trade credit",
        behavioral_category: "stored_value",
        stored_value_account_type: "trade_credit",
        external_reference_policy: "omitted",
        allows_refund: true,
        allows_original_tender_refund: true,
        allows_generic_refund_destination: false,
        allows_refund_instrument_replacement: false
      },
      {
        code: "gift_card",
        name: "Gift card",
        behavioral_category: "stored_value",
        stored_value_account_type: "gift_card",
        external_reference_policy: "omitted",
        allows_refund: true,
        allows_original_tender_refund: true,
        allows_generic_refund_destination: false,
        allows_refund_instrument_replacement: true
      }
    ].freeze

    def self.seed!
      SEEDS.each do |attrs|
        type = TenderType.find_or_initialize_by(code: attrs[:code])
        type.assign_attributes(
          name: type.new_record? ? attrs[:name] : type.name,
          behavioral_category: attrs[:behavioral_category],
          stored_value_account_type: attrs[:stored_value_account_type],
          external_reference_policy: type.new_record? ? attrs[:external_reference_policy] : type.external_reference_policy,
          allows_refund: type.new_record? ? attrs[:allows_refund] : type.allows_refund,
          allows_original_tender_refund: type.new_record? ? attrs.fetch(:allows_original_tender_refund, false) : type.allows_original_tender_refund,
          allows_generic_refund_destination: type.new_record? ? attrs.fetch(:allows_generic_refund_destination, false) : type.allows_generic_refund_destination,
          allows_refund_instrument_replacement: type.new_record? ? attrs.fetch(:allows_refund_instrument_replacement, false) : type.allows_refund_instrument_replacement,
          system_protected: true,
          active: type.new_record? ? true : type.active
        )
        type.allows_refund = true if attrs[:code] == "cash"
        type.save!
      end
    end
  end
end
