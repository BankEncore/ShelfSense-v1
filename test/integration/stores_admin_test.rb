# frozen_string_literal: true

require "test_helper"

class StoresAdminTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
  end

  test "receipt message textareas are enabled only in custom mode" do
    sign_in_as("admin")

    get edit_admin_store_path(@store)
    assert_response :success
    assert_select "textarea[name='store[receipt_header]'][disabled]"
    assert_select "textarea[name='store[receipt_footer]'][disabled]"
    assert_select "[data-controller='store-receipt-messages']"

    @store.update!(receipt_header_mode: "custom", receipt_header: "Thank you for shopping local")
    get edit_admin_store_path(@store)
    assert_response :success
    assert_select "textarea[name='store[receipt_header]']:not([disabled])"
    assert_select "textarea[name='store[receipt_footer]'][disabled]"
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end
end
