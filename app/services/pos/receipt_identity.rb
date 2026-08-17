# frozen_string_literal: true

module Pos
  module ReceiptIdentity
    module_function

    def reference(store_number:, register_number:, receipt_sequence:)
      "S#{pad(store_number, 3)}-R#{pad(register_number, 2)}-T#{pad(receipt_sequence, 7)}"
    end

    def header(store_number:, register_number:, receipt_sequence:)
      "Store: #{pad(store_number, 3)}   Reg: #{pad(register_number, 2)}   Trans: #{pad(receipt_sequence, 7)}"
    end

    def pad(value, min_width)
      digits = value.to_s
      return digits if digits.length >= min_width

      digits.rjust(min_width, "0")
    end
  end
end
