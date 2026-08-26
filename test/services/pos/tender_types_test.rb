# frozen_string_literal: true

require "test_helper"

class Pos::TenderTypesTest < ActiveSupport::TestCase
  test "seed creates protected stored-value tenders and is idempotent" do
    Pos::TenderTypes.seed!

    %w[store_credit trade_credit gift_card].each do |code|
      type = TenderType.find_by!(code: code)
      assert type.system_protected?
      assert type.active?
      assert_equal "stored_value", type.behavioral_category
      assert_equal code, type.stored_value_account_type
      assert type.allows_refund?
    end

    store_credit = TenderType.find_by!(code: "store_credit")
    trade_credit = TenderType.find_by!(code: "trade_credit")
    gift_card = TenderType.find_by!(code: "gift_card")
    assert store_credit.allows_generic_refund_destination?
    assert_not trade_credit.allows_generic_refund_destination?
    assert gift_card.allows_refund_instrument_replacement?

    snapshot = TenderType.order(:code).pluck(:code, :behavioral_category, :stored_value_account_type)
    Pos::TenderTypes.seed!
    assert_equal snapshot, TenderType.order(:code).pluck(:code, :behavioral_category, :stored_value_account_type)
  end
end
