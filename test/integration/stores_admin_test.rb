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
    assert_select "[data-store-receipt-messages]"

    @store.update!(receipt_header_mode: "custom", receipt_header: "Thank you for shopping local")
    get edit_admin_store_path(@store)
    assert_response :success
    assert_select "textarea[name='store[receipt_header]']:not([disabled])"
    assert_select "textarea[name='store[receipt_footer]'][disabled]"
  end

  test "store update audits receipt identity and address fields" do
    sign_in_as("admin")

    patch admin_store_path(@store), params: {
      store: {
        phone: "555-0100",
        street_address_1: "1 Main St",
        street_address_2: "Suite 2",
        city: "Springfield",
        region_code: "IL",
        postal_code: "62701",
        country_code: "US",
        lock_version: @store.lock_version
      }
    }
    assert_redirected_to admin_store_path(@store)

    event = AuditEvent.where(action: "stores.update").order(:created_at).last
    assert_equal "555-0100", event.after_values.fetch("phone")
    assert_equal "1 Main St", event.after_values.fetch("street_address_1")
    assert_equal "Suite 2", event.after_values.fetch("street_address_2")
    assert_equal "Springfield", event.after_values.fetch("city")
    assert_equal "IL", event.after_values.fetch("region_code")
    assert_equal "62701", event.after_values.fetch("postal_code")
    assert_equal "US", event.after_values.fetch("country_code")
    assert event.after_values.key?("legal_name")
    assert event.after_values.key?("receipt_header_mode")
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end
end
