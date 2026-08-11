# frozen_string_literal: true

require "test_helper"

class GlAccountTest < ActiveSupport::TestCase
  test "account_number is unique" do
    gl_account(account_number: "1000", account_type: "asset", account_category: "cash")
    duplicate = GlAccount.new(
      account_number: "1000",
      name: "Dup",
      account_type: "asset",
      account_category: "cash"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:account_number], "has already been taken"
  end

  test "parent must have the same account type" do
    parent = gl_account(account_number: "1100", account_type: "asset", account_category: "cash")
    child = GlAccount.new(
      account_number: "4100",
      name: "Sales child",
      account_type: "revenue",
      account_category: "sales",
      parent: parent
    )
    assert_not child.valid?
    assert_includes child.errors[:parent_id], "must have the same account type"
  end

  test "parent hierarchy cannot cycle" do
    a = gl_account(account_number: "2000", account_type: "liability", account_category: "accounts_payable")
    b = gl_account(account_number: "2100", account_type: "liability", account_category: "accounts_payable", parent: a)

    a.parent = b
    assert_not a.valid?
    assert_includes a.errors[:parent_id], "would create a hierarchy cycle"
  end

  test "account cannot parent itself" do
    account = gl_account(account_number: "3000", account_type: "equity", account_category: "equity")
    account.parent_id = account.id
    assert_not account.valid?
    assert_includes account.errors[:parent_id], "cannot reference itself"
  end

  test "category derives account type" do
    account = GlAccount.new(
      account_number: "5000",
      name: "COGS",
      account_category: "cost_of_goods_sold",
      account_type: "asset"
    )
    assert account.valid?
    assert_equal "expense", account.account_type
  end

  test "database rejects inconsistent category type pairs" do
    assert_raises(ActiveRecord::StatementInvalid) do
      GlAccount.insert!({
        id: SecureRandom.uuid_v7,
        account_number: "9999",
        name: "Bad",
        account_category: "sales",
        account_type: "asset",
        posting_allowed: true,
        active: true,
        display_order: 0,
        lock_version: 0,
        created_at: Time.current,
        updated_at: Time.current
      })
    end
  end
end
