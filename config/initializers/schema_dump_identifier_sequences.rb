# frozen_string_literal: true

module Shelfsense
  module SchemaDumpIdentifierSequences
    SEQUENCE_SQL = [
      "CREATE SEQUENCE IF NOT EXISTS shelfsense_sku_221_seq AS bigint MINVALUE 0 MAXVALUE 999999999 START WITH 0 INCREMENT BY 1 NO CYCLE",
      "CREATE SEQUENCE IF NOT EXISTS shelfsense_product_222_seq AS bigint MINVALUE 0 MAXVALUE 999999999 START WITH 0 INCREMENT BY 1 NO CYCLE"
    ].freeze

    def tables(stream)
      stream.puts "  # ShelfSense identifier allocation sequences (not owned by a table column)."
      SEQUENCE_SQL.each do |sql|
        stream.puts "  execute #{sql.inspect}"
      end
      stream.puts
      super
    end
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::SchemaDumper.prepend(Shelfsense::SchemaDumpIdentifierSequences)
end
