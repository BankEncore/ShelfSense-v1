# frozen_string_literal: true

require "test_helper"

class CustomersAdminTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
  end

  test "admin can create a customer with audit" do
    sign_in_as("admin")

    post admin_customers_path, params: {
      customer: { display_name: "Jamie Reader", email: "jamie@example.com" }
    }
    customer = Customer.find_by!(display_name: "Jamie Reader")
    assert_redirected_to admin_customer_path(customer)
    assert AuditEvent.exists?(action: "customers.create", subject_id: customer.id)
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end
end
