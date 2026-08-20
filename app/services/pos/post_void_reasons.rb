# frozen_string_literal: true

module Pos
  module PostVoidReasons
    module_function

    CATALOG = {
      "entered_in_error" => "Entered in error",
      "duplicate_transaction" => "Duplicate transaction",
      "test_transaction" => "Test transaction",
      "wrong_register" => "Wrong register",
      "other" => "Other"
    }.freeze

    def name_for!(code)
      CATALOG.fetch(code.to_s) { raise Pos::Error, "reason is not valid" }
    end

    def require_note?(code)
      code.to_s == "other"
    end

    ENTRIES = CATALOG.map { |code, name| { code: code, name: name } }.freeze
  end
end
