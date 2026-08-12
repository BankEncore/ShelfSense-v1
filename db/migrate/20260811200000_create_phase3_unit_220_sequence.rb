# frozen_string_literal: true

class CreatePhase3Unit220Sequence < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE SEQUENCE IF NOT EXISTS shelfsense_unit_220_seq
        AS bigint
        MINVALUE 0
        MAXVALUE 999999999
        START WITH 0
        INCREMENT BY 1
        NO CYCLE
    SQL
  end

  def down
    execute "DROP SEQUENCE IF EXISTS shelfsense_unit_220_seq"
  end
end
