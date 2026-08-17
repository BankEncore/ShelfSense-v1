# frozen_string_literal: true

module Pos
  class CompletedTransactionFacts
    def initialize(envelope)
      @envelope = Idempotency::CanonicalJson.normalize(envelope)
      freeze
    end

    attr_reader :envelope

    def envelope_hash
      Idempotency::CanonicalJson.hash(@envelope)
    end

    def receipt_sequence
      @envelope.fetch("receipt").fetch("sequence")
    end

    def store_number
      @envelope.fetch("receipt").fetch("store_number")
    end

    def register_number
      @envelope.fetch("receipt").fetch("register_number")
    end

    def transaction_reference
      @envelope.fetch("receipt").fetch("reference")
    end

    def occurred_at
      @envelope.fetch("transaction").fetch("occurred_at")
    end

    def business_date
      @envelope.fetch("transaction").fetch("business_date")
    end

    def verify!
      receipt = @envelope.fetch("receipt")
      raise Pos::Error, "completed envelope is missing receipt sequence" if receipt["sequence"].blank?
      raise Pos::Error, "completed envelope is missing receipt reference" if receipt["reference"].blank?
      raise Pos::Error, "completed envelope is missing store number" if receipt["store_number"].blank?
      raise Pos::Error, "completed envelope is missing register number" if receipt["register_number"].blank?
      raise Pos::Error, "completed envelope fact_type is invalid" unless @envelope.dig("operation", "fact_type") == PosOperation::FACT_TYPE
      raise Pos::Error, "completed envelope schema_version is invalid" unless @envelope.fetch("schema_version") == 1
    end
  end
end
