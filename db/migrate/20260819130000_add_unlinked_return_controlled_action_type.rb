# frozen_string_literal: true

class AddUnlinkedReturnControlledActionType < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :pos_controlled_actions, name: "pos_controlled_actions_type_valid"
    add_check_constraint :pos_controlled_actions,
                         "action_type IN ('price_override', 'line_discount', 'tax_class_override', 'unlinked_return')",
                         name: "pos_controlled_actions_type_valid"
  end

  def down
    remove_check_constraint :pos_controlled_actions, name: "pos_controlled_actions_type_valid"
    add_check_constraint :pos_controlled_actions,
                         "action_type IN ('price_override', 'line_discount', 'tax_class_override')",
                         name: "pos_controlled_actions_type_valid"
  end
end
