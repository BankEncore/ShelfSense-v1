# frozen_string_literal: true

class EnforceGlAccountCategoryTypeMapping < ActiveRecord::Migration[8.1]
  CATEGORY_TO_TYPE = {
    "cash" => "asset",
    "accounts_receivable" => "asset",
    "inventory" => "asset",
    "other_current_asset" => "asset",
    "fixed_asset" => "asset",
    "accounts_payable" => "liability",
    "other_current_liability" => "liability",
    "long_term_liability" => "liability",
    "equity" => "equity",
    "sales" => "revenue",
    "sales_returns" => "revenue",
    "other_revenue" => "revenue",
    "cost_of_goods_sold" => "expense",
    "freight_in" => "expense",
    "inventory_shrinkage" => "expense",
    "inventory_adjustment" => "expense",
    "inventory_write_down" => "expense",
    "other_expense" => "expense"
  }.freeze

  def up
    bad = connection.select_all(<<~SQL.squish)
      SELECT id, account_number, account_category, account_type
      FROM gl_accounts
    SQL

    inconsistent = bad.reject do |row|
      CATEGORY_TO_TYPE[row["account_category"]] == row["account_type"]
    end
    if inconsistent.any?
      report = inconsistent.map { |r| "#{r["account_number"]}(#{r["account_category"]}/#{r["account_type"]})" }.join(", ")
      raise ActiveRecord::IrreversibleMigration, "Inconsistent GL category/type pairs: #{report}"
    end

    clauses = CATEGORY_TO_TYPE.map do |category, type|
      "(account_category = #{connection.quote(category)} AND account_type = #{connection.quote(type)})"
    end.join(" OR ")

    add_check_constraint :gl_accounts, clauses, name: "gl_accounts_category_matches_type"
  end

  def down
    remove_check_constraint :gl_accounts, name: "gl_accounts_category_matches_type"
  end
end
