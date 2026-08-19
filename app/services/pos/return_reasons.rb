# frozen_string_literal: true

module Pos
  module ReturnReasons
    ENTRIES = [
      { code: "changed_mind", name: "Changed mind" },
      { code: "defective", name: "Defective" },
      { code: "wrong_item", name: "Wrong item" },
      { code: "duplicate_purchase", name: "Duplicate purchase" },
      { code: "other", name: "Other" }
    ].freeze
    CODES = ENTRIES.map { |entry| entry[:code] }.freeze

    module_function

    def name_for!(code)
      entry = ENTRIES.find { |item| item[:code] == code.to_s }
      raise Pos::Error, "return reason is invalid" if entry.nil?

      entry[:name]
    end

    def require_note?(code)
      code.to_s == "other"
    end
  end
end
