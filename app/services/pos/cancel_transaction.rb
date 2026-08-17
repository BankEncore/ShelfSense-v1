# frozen_string_literal: true

module Pos
  class CancelTransaction
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
        transaction.update!(status: "cancelled", cancelled_at: Time.current)
        Audit::Recorder.record!(
          action: "pos.transaction_cancelled",
          outcome: "succeeded",
          actor_user: @actor,
          actor_label: @actor.display_name,
          store: transaction.store,
          register: transaction.register,
          subject: transaction
        )
        transaction
      end
    end
  end
end
