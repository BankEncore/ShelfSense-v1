# frozen_string_literal: true

class AllowCompensatingReceiptCorrectionQuantity < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :purchase_receipt_line_corrections, name: "prl_corrections_quantity_matches_type"
    add_check_constraint :purchase_receipt_line_corrections,
                         <<~SQL.squish,
                           (correction_type = 'quantity_reversal' AND quantity > 0)
                           OR (correction_type = 'compensating_adjustment_reference' AND quantity > 0)
                           OR (correction_type = 'cost_correction' AND quantity IS NULL)
                         SQL
                         name: "prl_corrections_quantity_matches_type"

    remove_check_constraint :purchase_receipt_line_corrections, name: "prl_corrections_cost_value_present"
    add_check_constraint :purchase_receipt_line_corrections,
                         <<~SQL.squish,
                           (correction_type = 'cost_correction' AND value_delta_cents IS NOT NULL AND value_delta_cents <> 0)
                           OR (correction_type = 'compensating_adjustment_reference' AND value_delta_cents IS NOT NULL)
                           OR (correction_type = 'quantity_reversal')
                         SQL
                         name: "prl_corrections_cost_value_present"
  end

  def down
    remove_check_constraint :purchase_receipt_line_corrections, name: "prl_corrections_quantity_matches_type"
    add_check_constraint :purchase_receipt_line_corrections,
                         "(correction_type = 'quantity_reversal' AND quantity > 0) OR (correction_type <> 'quantity_reversal' AND quantity IS NULL)",
                         name: "prl_corrections_quantity_matches_type"

    remove_check_constraint :purchase_receipt_line_corrections, name: "prl_corrections_cost_value_present"
    add_check_constraint :purchase_receipt_line_corrections,
                         "(correction_type = 'cost_correction' AND value_delta_cents IS NOT NULL AND value_delta_cents <> 0) OR (correction_type <> 'cost_correction')",
                         name: "prl_corrections_cost_value_present"
  end
end
