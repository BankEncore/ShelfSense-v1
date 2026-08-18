# frozen_string_literal: true

module Pos
  class AbandonTender
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(transaction:, actor:, expected_lock_version:)
      @transaction = transaction
      @actor = actor
      @expected_lock_version = expected_lock_version
    end

    def call
      Pos::Support.authorize!(@actor, @transaction.store)
      Pos::Support.require_active_context!(@transaction.store, @transaction.register)
      Pos::Support.require_transaction_cashier!(@actor, @transaction)

      PosTransaction.transaction do
        transaction = Pos::Support.lock_working_transaction!(@transaction, @expected_lock_version)
        if Pos::Support.clear_working_tenders!(transaction)
          Pos::Support.touch_working_transaction!(transaction)
        end
        transaction
      end
    end
  end
end
