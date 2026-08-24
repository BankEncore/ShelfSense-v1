# frozen_string_literal: true

require "test_helper"

module Customers
  class SuggestDuplicatesTest < ActiveSupport::TestCase
    setup do
      @existing = Customer.create!(
        display_name: "Jamie Lee Reader",
        email: "jamie@example.com",
        phone: "555-010-1001"
      )
    end

    test "strong match on email" do
      suggestions = Customers::SuggestDuplicates.call(
        attributes: { display_name: "Other", email: "Jamie@Example.com", phone: nil }
      )
      assert_equal 1, suggestions.size
      assert_equal :strong, suggestions.first.match_strength
      assert_equal "email", suggestions.first.matched_on
    end

    test "weak match on name tokens" do
      suggestions = Customers::SuggestDuplicates.call(
        attributes: { display_name: "Jamie Lee Someone", email: nil, phone: nil }
      )
      assert_equal 1, suggestions.size
      assert_equal :weak, suggestions.first.match_strength
    end

    test "weak match derives display name from given and family when blank" do
      suggestions = Customers::SuggestDuplicates.call(
        attributes: {
          display_name: "",
          given_name: "Jamie",
          family_name: "Lee",
          email: nil,
          phone: nil
        }
      )
      assert_equal 1, suggestions.size
      assert_equal :weak, suggestions.first.match_strength
      assert_equal @existing.id, suggestions.first.customer.id
    end

    test "excludes merged aliases as candidates" do
      survivor = Customer.create!(display_name: "Survivor", email: "s@example.com", phone: "555-999-9999")
      @existing.update!(active: false, merged_into_customer: survivor)

      suggestions = Customers::SuggestDuplicates.call(
        attributes: { display_name: "X", email: "jamie@example.com", phone: nil }
      )
      assert_empty suggestions.select { |s| s.customer.id == @existing.id }
    end
  end
end
