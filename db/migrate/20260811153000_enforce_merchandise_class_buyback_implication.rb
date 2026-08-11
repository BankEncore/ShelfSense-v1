# frozen_string_literal: true

class EnforceMerchandiseClassBuybackImplication < ActiveRecord::Migration[8.1]
  def up
    bad = connection.select_all(<<~SQL.squish)
      SELECT id, code FROM merchandise_classes
      WHERE buyback_allowed = TRUE
        AND NOT (used_merchandise_allowed = TRUE AND inventory_mode = 'inventory')
    SQL
    if bad.any?
      report = bad.map { |r| r["code"] }.join(", ")
      raise ActiveRecord::IrreversibleMigration,
            "buyback_allowed requires used_merchandise_allowed and inventory mode for: #{report}"
    end

    add_check_constraint :merchandise_classes,
                         "NOT buyback_allowed OR (used_merchandise_allowed AND inventory_mode = 'inventory')",
                         name: "merchandise_classes_buyback_implies_used_inventory"
  end

  def down
    remove_check_constraint :merchandise_classes, name: "merchandise_classes_buyback_implies_used_inventory"
  end
end
