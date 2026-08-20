# frozen_string_literal: true

require "application_system_test_case"

class StoreReceiptMessagesTest < ApplicationSystemTestCase
  setup do
    bootstrap!
  end

  test "selecting custom enables the store receipt textarea" do
    visit new_session_path
    fill_in "session_username", with: "admin"
    fill_in "session_password", with: "correct-horse-battery"
    find_field("session_password").send_keys :enter
    assert_text "Signed in successfully"

    visit edit_admin_store_path(Store.find_by!(code: "main"))
    assert_field "store_receipt_header", disabled: true
    assert_field "store_receipt_footer", disabled: true

    within("fieldset", text: "Receipt header") do
      choose "Use custom header"
      assert_field "store_receipt_header", disabled: false
      fill_in "store_receipt_header", with: "Thank you for shopping local"
      choose "Use organization default"
      assert_field "store_receipt_header", disabled: true
    end

    within("fieldset", text: "Receipt footer") do
      choose "Use custom footer"
      assert_field "store_receipt_footer", disabled: false
    end
  end
end
