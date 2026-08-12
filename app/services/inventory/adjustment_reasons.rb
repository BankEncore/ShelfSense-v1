# frozen_string_literal: true

module Inventory
  module AdjustmentReasons
    SEEDS = [
      { code: "opening_inventory", name: "Opening inventory", direction: "increase", cost_required_for_increase: true },
      { code: "found_inventory", name: "Found inventory", direction: "increase", cost_required_for_increase: true },
      { code: "shrinkage", name: "Shrinkage", direction: "decrease", cost_required_for_increase: false },
      { code: "damage_removal", name: "Damage removal", direction: "decrease", cost_required_for_increase: false },
      { code: "data_correction", name: "Data correction", direction: "either", cost_required_for_increase: true },
      {
        code: "reversal",
        name: "Reversal",
        direction: "either",
        cost_required_for_increase: false,
        system_protected: true,
        notes_required: true
      }
    ].freeze

    def self.seed!
      SEEDS.each do |attrs|
        reason = AdjustmentReason.find_or_initialize_by(code: attrs[:code])
        reason.assign_attributes(
          name: attrs[:name],
          direction: attrs[:direction],
          cost_required_for_increase: attrs.fetch(:cost_required_for_increase, true),
          notes_required: attrs.fetch(:notes_required, false),
          allows_quantity_tracking: true,
          allows_individual_tracking: true,
          system_protected: attrs.fetch(:system_protected, false),
          active: true
        )
        reason.save!
      end
    end
  end
end
