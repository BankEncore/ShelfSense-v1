# frozen_string_literal: true

module Identifiers
  class Generator
    class ExhaustedError < StandardError; end

    SEQUENCE_BY_PREFIX = {
      "220" => "shelfsense_unit_220_seq",
      "221" => "shelfsense_sku_221_seq",
      "222" => "shelfsense_product_222_seq"
    }.freeze

    def self.next_ean13!(prefix)
      new.next_ean13!(prefix)
    end

    def next_ean13!(prefix)
      sequence = SEQUENCE_BY_PREFIX.fetch(prefix) { raise ArgumentError, "unsupported prefix #{prefix}" }
      connection = ActiveRecord::Base.connection

      payload =
        begin
          connection.create_savepoint("shelfsense_id_seq")
          value = connection.select_value("SELECT nextval(#{connection.quote(sequence)})")
          connection.release_savepoint("shelfsense_id_seq")
          value
        rescue ActiveRecord::StatementInvalid => e
          connection.rollback_to_savepoint("shelfsense_id_seq")
          raise ExhaustedError, "identifier sequence #{sequence} is exhausted" if e.message.match?(/sequence.*maxvalue|reached maximum/i)

          raise
        end

      raise ExhaustedError, "identifier sequence #{sequence} is exhausted" if payload.nil? || payload.to_i > 999_999_999

      Ean13.complete(prefix, format("%09d", payload.to_i))
    end
  end
end
