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
      raise Pos::Error, "completed envelope is missing receipt sequence" unless positive_integer?(receipt["sequence"])
      raise Pos::Error, "completed envelope is missing receipt reference" if receipt["reference"].blank?
      raise Pos::Error, "completed envelope is missing store number" unless positive_integer?(receipt["store_number"])
      raise Pos::Error, "completed envelope is missing register number" unless positive_integer?(receipt["register_number"])
      raise Pos::Error, "completed envelope fact_type is invalid" unless @envelope.dig("operation", "fact_type") == PosOperation::FACT_TYPE
      version = @envelope.fetch("schema_version")
      raise Pos::Error, "completed envelope schema_version is invalid" unless [ 1, 2 ].include?(version)
      return unless version == 2

      signed_net = @envelope.fetch("transaction")["signed_net_cents"]
      raise Pos::Error, "completed envelope is missing signed_net_cents" unless signed_net.is_a?(Integer)
    end

    private

    def positive_integer?(value)
      value.is_a?(Integer) && value.positive?
    end
  end
end
