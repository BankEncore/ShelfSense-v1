# frozen_string_literal: true

class AddPhase5CashAccountability < ActiveRecord::Migration[8.1]
  FINALIZED_SNAPSHOTS = %w[
    finalized_transaction_count
    finalized_subtotal_cents
    finalized_tax_cents
    finalized_total_cents
    finalized_cash_payment_cents
    finalized_session_count
    finalized_opening_float_cents_sum
    finalized_closing_expected_cash_cents_sum
    finalized_closing_count_cents_sum
    finalized_closing_variance_cents_sum
  ].freeze

  def up
    add_column :pos_sessions, :opening_float_cents, :bigint, null: false, default: 0
    add_column :pos_sessions, :closing_expected_cash_cents, :bigint
    add_column :pos_sessions, :closing_count_cents, :bigint
    add_column :pos_sessions, :closing_variance_cents, :bigint

    add_column :pos_reporting_periods, :finalized_transaction_count, :integer
    add_column :pos_reporting_periods, :finalized_subtotal_cents, :bigint
    add_column :pos_reporting_periods, :finalized_tax_cents, :bigint
    add_column :pos_reporting_periods, :finalized_total_cents, :bigint
    add_column :pos_reporting_periods, :finalized_cash_payment_cents, :bigint
    add_column :pos_reporting_periods, :finalized_session_count, :integer
    add_column :pos_reporting_periods, :finalized_opening_float_cents_sum, :bigint
    add_column :pos_reporting_periods, :finalized_closing_expected_cash_cents_sum, :bigint
    add_column :pos_reporting_periods, :finalized_closing_count_cents_sum, :bigint
    add_column :pos_reporting_periods, :finalized_closing_variance_cents_sum, :bigint
    add_column :pos_reporting_periods, :finalized_by_user_id, :uuid
    add_foreign_key :pos_reporting_periods, :users, column: :finalized_by_user_id
    add_index :pos_reporting_periods, :finalized_by_user_id

    execute <<~SQL.squish
      UPDATE pos_sessions
      SET closing_expected_cash_cents = 0,
          closing_count_cents = 0,
          closing_variance_cents = 0
      WHERE status = 'closed'
        AND closing_count_cents IS NULL
    SQL

    remove_check_constraint :pos_sessions, name: "pos_sessions_closed_at_matches_status"
    add_check_constraint :pos_sessions, <<~SQL.squish, name: "pos_sessions_closed_at_matches_status"
      (status = 'open' AND closed_at IS NULL
        AND closing_expected_cash_cents IS NULL
        AND closing_count_cents IS NULL
        AND closing_variance_cents IS NULL)
      OR
      (status = 'closed' AND closed_at IS NOT NULL
        AND closing_expected_cash_cents IS NOT NULL
        AND closing_count_cents IS NOT NULL
        AND closing_variance_cents IS NOT NULL)
    SQL
    add_check_constraint :pos_sessions, "opening_float_cents >= 0", name: "pos_sessions_opening_float_nonnegative"
    add_check_constraint :pos_sessions,
                         "closing_expected_cash_cents IS NULL OR closing_expected_cash_cents >= 0",
                         name: "pos_sessions_closing_expected_nonnegative"
    add_check_constraint :pos_sessions,
                         "closing_count_cents IS NULL OR closing_count_cents >= 0",
                         name: "pos_sessions_closing_count_nonnegative"
    add_check_constraint :pos_sessions, <<~SQL.squish, name: "pos_sessions_closing_variance_matches_count"
      closing_variance_cents IS NULL
      OR closing_variance_cents = closing_count_cents - closing_expected_cash_cents
    SQL

    remove_check_constraint :pos_reporting_periods, name: "pos_reporting_periods_closed_at_matches_status"
    add_check_constraint :pos_reporting_periods, period_status_sql, name: "pos_reporting_periods_closed_at_matches_status"
    add_nonnegative_period_checks
    add_check_constraint :pos_reporting_periods, <<~SQL.squish, name: "pos_reporting_periods_finalized_variance_matches_sums"
      finalized_closing_variance_cents_sum IS NULL
      OR finalized_closing_variance_cents_sum =
           finalized_closing_count_cents_sum - finalized_closing_expected_cash_cents_sum
    SQL
  end

  def down
    remove_check_constraint :pos_reporting_periods, name: "pos_reporting_periods_finalized_variance_matches_sums"
    remove_nonnegative_period_checks
    remove_check_constraint :pos_reporting_periods, name: "pos_reporting_periods_closed_at_matches_status"
    add_check_constraint :pos_reporting_periods,
                         "(status = 'open' AND closed_at IS NULL) OR (status = 'finalized' AND closed_at IS NOT NULL)",
                         name: "pos_reporting_periods_closed_at_matches_status"

    remove_check_constraint :pos_sessions, name: "pos_sessions_opening_float_nonnegative"
    remove_check_constraint :pos_sessions, name: "pos_sessions_closing_expected_nonnegative"
    remove_check_constraint :pos_sessions, name: "pos_sessions_closing_count_nonnegative"
    remove_check_constraint :pos_sessions, name: "pos_sessions_closing_variance_matches_count"
    remove_check_constraint :pos_sessions, name: "pos_sessions_closed_at_matches_status"
    add_check_constraint :pos_sessions,
                         "(status = 'open' AND closed_at IS NULL) OR (status = 'closed' AND closed_at IS NOT NULL)",
                         name: "pos_sessions_closed_at_matches_status"

    remove_foreign_key :pos_reporting_periods, column: :finalized_by_user_id
    remove_index :pos_reporting_periods, :finalized_by_user_id
    remove_column :pos_reporting_periods, :finalized_by_user_id
    FINALIZED_SNAPSHOTS.each { |column| remove_column :pos_reporting_periods, column }

    remove_column :pos_sessions, :opening_float_cents
    remove_column :pos_sessions, :closing_expected_cash_cents
    remove_column :pos_sessions, :closing_count_cents
    remove_column :pos_sessions, :closing_variance_cents
  end

  private

  def period_status_sql
    nulls = ([ "finalized_by_user_id" ] + FINALIZED_SNAPSHOTS).map { |column| "#{column} IS NULL" }.join(" AND ")
    presents = ([ "finalized_by_user_id" ] + FINALIZED_SNAPSHOTS).map { |column| "#{column} IS NOT NULL" }.join(" AND ")
    <<~SQL.squish
      (status = 'open' AND closed_at IS NULL AND #{nulls})
      OR
      (status = 'finalized' AND closed_at IS NOT NULL AND #{presents})
    SQL
  end

  def add_nonnegative_period_checks
    {
      "pos_reporting_periods_finalized_transaction_count_nonnegative" => "finalized_transaction_count",
      "pos_reporting_periods_finalized_subtotal_nonnegative" => "finalized_subtotal_cents",
      "pos_reporting_periods_finalized_tax_nonnegative" => "finalized_tax_cents",
      "pos_reporting_periods_finalized_total_nonnegative" => "finalized_total_cents",
      "pos_reporting_periods_finalized_cash_payment_nonnegative" => "finalized_cash_payment_cents",
      "pos_reporting_periods_finalized_session_count_nonnegative" => "finalized_session_count",
      "pos_reporting_periods_finalized_opening_float_sum_nonnegative" => "finalized_opening_float_cents_sum",
      "pos_reporting_periods_finalized_closing_expected_sum_nonnegative" => "finalized_closing_expected_cash_cents_sum",
      "pos_reporting_periods_finalized_closing_count_sum_nonnegative" => "finalized_closing_count_cents_sum"
    }.each do |name, column|
      add_check_constraint :pos_reporting_periods, "#{column} IS NULL OR #{column} >= 0", name: name
    end
  end

  def remove_nonnegative_period_checks
    %w[
      pos_reporting_periods_finalized_transaction_count_nonnegative
      pos_reporting_periods_finalized_subtotal_nonnegative
      pos_reporting_periods_finalized_tax_nonnegative
      pos_reporting_periods_finalized_total_nonnegative
      pos_reporting_periods_finalized_cash_payment_nonnegative
      pos_reporting_periods_finalized_session_count_nonnegative
      pos_reporting_periods_finalized_opening_float_sum_nonnegative
      pos_reporting_periods_finalized_closing_expected_sum_nonnegative
      pos_reporting_periods_finalized_closing_count_sum_nonnegative
    ].each { |name| remove_check_constraint :pos_reporting_periods, name: name }
  end
end
