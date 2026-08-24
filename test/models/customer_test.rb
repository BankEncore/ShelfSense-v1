# frozen_string_literal: true

require "test_helper"

class CustomerTest < ActiveSupport::TestCase
  test "requires display name" do
    customer = Customer.new
    assert_not customer.valid?
    assert_includes customer.errors[:display_name], "can't be blank"
  end

  test "creates with uuid and optional names" do
    customer = Customer.create!(display_name: "Alex", given_name: "Alexandra", family_name: "Reader")
    assert customer.id.present?
    assert customer.active?
    assert_equal "Alexandra", customer.given_name
    assert_equal "Reader", customer.family_name
    assert customer.canonical?
  end

  test "normalizes email and phone to E.164" do
    customer = Customer.create!(
      display_name: "Norm",
      email: "  Pat@Example.COM ",
      phone: "(555) 010-1234"
    )
    assert_equal "pat@example.com", customer.email_normalized
    assert_equal "+15550101234", customer.phone_normalized
  end

  test "preferred contact phone requires phone" do
    customer = Customer.new(display_name: "Pref", preferred_contact_method: "phone")
    assert_not customer.valid?
    assert_includes customer.errors[:preferred_contact_method], "requires a phone number"
  end

  test "merged customers cannot be reactivated" do
    survivor = Customer.create!(display_name: "Survivor", email: "s@example.com")
    source = Customer.create!(display_name: "Source", email: "a@example.com", active: false, merged_into_customer: survivor)
    assert source.merged?
    assert_includes source.reactivation_blockers.first, "merged"
  end

  test "canonical rejects merge chains" do
    top = Customer.create!(display_name: "Top", email: "top@example.com")
    mid = Customer.create!(display_name: "Mid", email: "mid@example.com", active: false, merged_into_customer: top)
    leaf = Customer.create!(display_name: "Leaf", email: "leaf@example.com")
    leaf.update_columns(active: false, merged_into_customer_id: mid.id)
    assert_raises(RuntimeError) { leaf.reload.canonical }
  end
end
