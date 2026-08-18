# frozen_string_literal: true

class AddPeriodTenderCategoryTotals < ActiveRecord::Migration[8.1]
  def change
    add_column :pos_reporting_periods, :finalized_card_payment_cents, :bigint
    add_column :pos_reporting_periods, :finalized_check_payment_cents, :bigint
    add_column :pos_reporting_periods, :finalized_other_payment_cents, :bigint

    add_check_constraint :pos_reporting_periods,
                         "finalized_card_payment_cents IS NULL OR finalized_card_payment_cents >= 0",
                         name: "pos_reporting_periods_finalized_card_payment_nonnegative"
    add_check_constraint :pos_reporting_periods,
                         "finalized_check_payment_cents IS NULL OR finalized_check_payment_cents >= 0",
                         name: "pos_reporting_periods_finalized_check_payment_nonnegative"
    add_check_constraint :pos_reporting_periods,
                         "finalized_other_payment_cents IS NULL OR finalized_other_payment_cents >= 0",
                         name: "pos_reporting_periods_finalized_other_payment_nonnegative"
  end
end
