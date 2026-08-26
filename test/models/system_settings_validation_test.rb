# frozen_string_literal: true

require "test_helper"

class SystemSettingsValidationTest < ActiveSupport::TestCase
  test "customer reservation days must be positive" do
    actor_user
    settings = SystemSettings.current
    settings.default_customer_reservation_expiration_days = 0
    assert_not settings.valid?
    assert settings.errors[:default_customer_reservation_expiration_days].any?
  end

  test "gift card voucher footer is limited like receipt messages" do
    actor_user
    settings = SystemSettings.current
    settings.gift_card_voucher_footer = "x" * (Store::RECEIPT_MESSAGE_LIMIT + 1)
    assert_not settings.valid?
    assert settings.errors[:gift_card_voucher_footer].any?

    settings.gift_card_voucher_footer = "  Treat this voucher like cash.  "
    assert settings.valid?
    settings.save!
    assert_equal "Treat this voucher like cash.", settings.reload.gift_card_voucher_footer
  end

  test "printed gift card voucher footer substitutes organization legal name" do
    actor_user
    settings = SystemSettings.current
    settings.update!(
      legal_name: "Example Books LLC",
      gift_card_voucher_footer: "Redeemable at {organization legal name}. Treat this voucher like cash."
    )
    assert_equal "Redeemable at Example Books LLC. Treat this voucher like cash.",
                 settings.printed_gift_card_voucher_footer
  end
end
