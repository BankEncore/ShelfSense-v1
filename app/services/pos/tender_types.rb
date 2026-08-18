# frozen_string_literal: true

module Pos
  module TenderTypes
    SEEDS = [
      { code: "cash", name: "Cash", behavioral_category: "cash", external_reference_policy: "omitted" },
      { code: "card", name: "External Card", behavioral_category: "card", external_reference_policy: "optional" },
      { code: "check", name: "Check", behavioral_category: "check", external_reference_policy: "optional" }
    ].freeze

    def self.seed!
      SEEDS.each do |attrs|
        type = TenderType.find_or_initialize_by(code: attrs[:code])
        type.assign_attributes(
          name: type.new_record? ? attrs[:name] : type.name,
          behavioral_category: attrs[:behavioral_category],
          external_reference_policy: type.new_record? ? attrs[:external_reference_policy] : type.external_reference_policy,
          system_protected: true,
          active: type.new_record? ? true : type.active
        )
        type.save!
      end
    end
  end
end
