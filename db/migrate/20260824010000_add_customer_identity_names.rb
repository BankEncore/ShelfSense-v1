# frozen_string_literal: true

class AddCustomerIdentityNames < ActiveRecord::Migration[8.1]
  def change
    change_table :customers, bulk: true do |t|
      t.string :given_name
      t.string :family_name
    end
  end
end
