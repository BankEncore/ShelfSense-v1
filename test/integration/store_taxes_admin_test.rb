# frozen_string_literal: true

require "test_helper"

class StoreTaxesAdminTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    tax_class(code: "physical_book", name: "Physical book")
  end

  test "admin can create a store tax for the current store" do
    sign_in_as("admin")

    post admin_store_taxes_path, params: {
      store_tax: {
        name: "Illinois State",
        rate_percent: "5.000",
        calculation_order: 1,
        applies_by_tax_class_id: { TaxClass.find_by!(code: "physical_book").id => "true" }
      }
    }
    store_tax = StoreTax.find_by!(code: "illinois_state")
    assert_redirected_to admin_store_tax_path(store_tax)
    assert_equal BigDecimal("5.000"), store_tax.rate_percent
    assert store_tax.store_tax_rules.find_by!(tax_class: TaxClass.find_by!(code: "physical_book")).applies
  end

  test "admin with multiple stores is sent to store selection instead of aborting" do
    Store.create!(
      store_number: "2",
      code: "east",
      name: "East Store",
      timezone: "America/New_York",
      country_code: "US"
    )
    sign_in_as("admin")

    get admin_store_taxes_path
    assert_redirected_to new_store_selection_path
  end

  test "associate is denied store_taxes.create" do
    associate = User.create!(
      username: "clerk",
      display_name: "Clerk",
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    RoleAssignment.create!(
      user: associate,
      role: Role.find_by!(key: "associate"),
      store: Store.first,
      assigned_by: User.find_by!(username: "admin"),
      effective_at: Time.current
    )

    sign_in_as("clerk")
    post admin_store_taxes_path, params: {
      store_tax: { name: "Denied", rate_percent: "1.000", calculation_order: 0 }
    }
    assert_redirected_to root_path
    assert_not StoreTax.exists?(code: "denied")
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end
end
