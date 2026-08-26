# frozen_string_literal: true

class AddGiftCardVoucherFooterToSystemSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :system_settings, :gift_card_voucher_footer, :text
  end
end
