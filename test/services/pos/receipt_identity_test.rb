# frozen_string_literal: true

require "test_helper"

class Pos::ReceiptIdentityTest < ActiveSupport::TestCase
  test "pads integer store 1 register 1 sequence 1 to the compact reference" do
    assert_equal "S001-R01-T0000001", Pos::ReceiptIdentity.reference(
      store_number: 1,
      register_number: 1,
      receipt_sequence: 1
    )
  end

  test "formats the printed receipt header from snapshots" do
    assert_equal "Store: 003   Reg: 02   Trans: 0018427", Pos::ReceiptIdentity.header(
      store_number: 3,
      register_number: 2,
      receipt_sequence: 18427
    )
  end
end
