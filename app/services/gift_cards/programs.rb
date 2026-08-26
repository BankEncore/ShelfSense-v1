# frozen_string_literal: true

module GiftCards
  module Programs
    SEEDS = [
      {
        code: "generated",
        name: "Store generated",
        number_authority: "system_generated",
        prefix: "801",
        reload_allowed: true,
        cash_out_policy: "permitted_when_eligible",
        cash_out_threshold_cents: 1000,
        cash_out_threshold_inclusive: true,
        cash_out_approval_required: false
      },
      {
        code: "manual",
        name: "Physical / external",
        number_authority: "manual_external",
        prefix: "802",
        reload_allowed: true,
        cash_out_policy: "prohibited",
        cash_out_approval_required: false
      }
    ].freeze

    def self.seed!
      SEEDS.each do |attrs|
        program = GiftCardProgram.find_or_initialize_by(code: attrs[:code])
        next if program.persisted? && program.activation_exists?

        program.assign_attributes(
          name: attrs[:name],
          number_authority: attrs[:number_authority],
          prefix: attrs[:prefix],
          number_length: GiftCardProgram::PHASE10_NUMBER_LENGTH,
          check_digit_algorithm: "luhn",
          reload_allowed: attrs.fetch(:reload_allowed, true),
          cash_out_policy: attrs[:cash_out_policy],
          cash_out_threshold_cents: attrs[:cash_out_threshold_cents],
          cash_out_threshold_inclusive: attrs.fetch(:cash_out_threshold_inclusive, true),
          cash_out_approval_required: attrs.fetch(:cash_out_approval_required, false),
          active: true
        )
        program.save!
      end
    end
  end
end
