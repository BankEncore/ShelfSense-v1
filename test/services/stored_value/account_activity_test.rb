# frozen_string_literal: true

require "test_helper"

module StoredValue
  class AccountActivityTest < ActiveSupport::TestCase
    setup do
      @bootstrap = bootstrap!
      @store = @bootstrap[:store]
      @actor = @bootstrap[:administrator]
      @customer = Customer.create!(display_name: "Ledger Customer", email: "ledger@example.com")
      @account = StoredValue::OpenAccount.call(account_type: "store_credit", customer: @customer)
    end

    test "paginates entries newest first and includes closed accounts" do
      26.times do |index|
        StoredValue::Post.call(
          operation_type: "issue",
          store: @store,
          performed_by: @actor,
          source_id: @account.id,
          idempotency_key: SecureRandom.uuid_v7,
          entries: [ { account: @account.reload, amount_cents: 1 } ],
          notes: "row #{index}"
        )
      end

      page1 = StoredValue::AccountActivity.call(account: @account, page: 1)
      assert_equal 25, page1.entries.size
      assert_equal 26, page1.total_count
      assert_equal 2, page1.total_pages

      page2 = StoredValue::AccountActivity.call(account: @account, page: 2)
      assert_equal 1, page2.entries.size
      assert_equal "issue", page2.entries.first.stored_value_operation.operation_type
    end
  end
end
