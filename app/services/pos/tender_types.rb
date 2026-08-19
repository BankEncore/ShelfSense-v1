# frozen_string_literal: true

module Pos
  module TenderTypes
    SEEDS = [
      { code: "cash", name: "Cash", behavioral_category: "cash", external_reference_policy: "omitted", allows_refund: true },
      { code: "card", name: "External Card", behavioral_category: "card", external_reference_policy: "optional", allows_refund: true },
      { code: "check", name: "Check", behavioral_category: "check", external_reference_policy: "optional", allows_refund: false }
    ].freeze

    def self.seed!
      SEEDS.each do |attrs|
        type = TenderType.find_or_initialize_by(code: attrs[:code])
        type.assign_attributes(
          name: type.new_record? ? attrs[:name] : type.name,
          behavioral_category: attrs[:behavioral_category],
          external_reference_policy: type.new_record? ? attrs[:external_reference_policy] : type.external_reference_policy,
          allows_refund: type.new_record? ? attrs[:allows_refund] : type.allows_refund,
          system_protected: true,
          active: type.new_record? ? true : type.active
        )
        type.allows_refund = true if attrs[:code] == "cash"
        type.save!
      end
    end
  end
end
