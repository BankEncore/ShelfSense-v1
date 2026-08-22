# frozen_string_literal: true

require "test_helper"

class CustomerTest < ActiveSupport::TestCase
  test "requires display name" do
    customer = Customer.new
    assert_not customer.valid?
    assert_includes customer.errors[:display_name], "can't be blank"
  end

  test "creates with uuid" do
    customer = Customer.create!(display_name: "Alex")
    assert customer.id.present?
    assert customer.active?
  end
end
