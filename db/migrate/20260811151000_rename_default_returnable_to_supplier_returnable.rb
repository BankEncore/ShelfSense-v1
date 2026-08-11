# frozen_string_literal: true

class RenameDefaultReturnableToSupplierReturnable < ActiveRecord::Migration[8.1]
  def change
    rename_column :merchandise_classes, :default_returnable, :default_supplier_returnable
  end
end
