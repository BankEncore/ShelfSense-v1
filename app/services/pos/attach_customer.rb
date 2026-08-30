# frozen_string_literal: true

module Pos
  class AttachCustomer
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(transaction:, actor:, expected_lock_version:, customer:)
      @transaction = transaction
      @actor = actor
      @expected_lock_version = expected_lock_version
      @customer = customer
    end

    def call
      Pos::Support.authorize!(@actor, @transaction.store)
      Pos::Support.require_active_context!(@transaction.store, @transaction.register)
      Pos::Support.require_transaction_cashier!(@actor, @transaction)
      raise Pos::Error, "customer is required" if @customer.blank?
      raise Pos::Error, "customer must be an active canonical customer" unless @customer.canonical? && @customer.active?

      PosTransaction.transaction do
        transaction = Pos::Support.lock_working_transaction!(@transaction, @expected_lock_version)
        if transaction.customer_id.present? && transaction.customer_id != @customer.id
          Pos::CustomerDependency.refuse_customer_change!(transaction)
        end
        transaction.update!(customer: @customer)
        Pos::Support.touch_working_transaction!(transaction)
        transaction
      end
    end
  end
end
