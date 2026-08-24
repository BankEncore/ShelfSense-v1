# frozen_string_literal: true

require "test_helper"

module Customers
  class SearchTest < ActiveSupport::TestCase
    setup do
      @bootstrap = bootstrap!
      @actor = @bootstrap[:administrator]
      @alex = Customer.create!(display_name: "Alex Reader", given_name: "Alex", email: "alex@example.com", phone: "555-010-1000")
      @pat = Customer.create!(display_name: "Pat Other", email: "pat@example.com", phone: "555-010-1999")
      @inactive = Customer.create!(display_name: "Inactive Alex", email: "inactive@example.com", active: false)
    end

    test "operational search matches name substring" do
      results = Customers::Search.call(query: "Alex", mode: :operational)
      assert_equal [ @alex.id ], results.map { |r| r.customer.id }
    end

    test "operational search matches normalized phone" do
      results = Customers::Search.call(query: "5550101000", mode: :operational)
      assert_equal [ @alex.id ], results.map { |r| r.customer.id }
    end

    test "admin index includes inactive" do
      results = Customers::Search.call(query: "Inactive", mode: :admin_index)
      assert_includes results.map { |r| r.customer.id }, @inactive.id
    end

    test "alias phone returns canonical survivor once" do
      Customers::MergeCustomers.call(
        source: @pat,
        survivor: @alex,
        actor: @actor,
        reason: "duplicate",
        idempotency_key: SecureRandom.uuid_v7
      )
      results = Customers::Search.call(query: "555-010-1999", mode: :operational)
      assert_equal 1, results.size
      assert_equal @alex.id, results.first.customer.id
      assert results.first.matched_former_customer
    end

    test "merged mode scopes before limit so late aliases remain visible" do
      survivor = Customer.create!(display_name: "Limit Survivor", email: "limit.survivor@example.com", phone: "555-700-0001")
      late_alias = Customer.create!(display_name: "ZZZ Late Alias", email: "late.alias@example.com", phone: "555-700-0002")
      Customers::MergeCustomers.call(
        source: late_alias,
        survivor: survivor,
        actor: @actor,
        reason: "limit test",
        idempotency_key: SecureRandom.uuid_v7
      )

      # Create many canonical rows that sort before the late alias alphabetically.
      5.times do |i|
        Customer.create!(
          display_name: "AAA Canonical #{i}",
          email: "aaa#{i}@example.com",
          phone: "555-710-000#{i}"
        )
      end

      results = Customers::Search.call(query: nil, mode: :merged, limit: 3)
      assert results.all? { |result| result.customer.merged? }
      assert_includes results.map { |result| result.customer.id }, late_alias.id
    end
  end
end
