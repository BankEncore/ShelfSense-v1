# frozen_string_literal: true

module Customers
  class MergeStoredValueAccounts
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(source:, survivor:, actor:, store:, merge_idempotency_operation:, correlation_id: nil)
      @source = source
      @survivor = survivor
      @actor = actor
      @store = store
      @merge_idempotency_operation = merge_idempotency_operation
      @correlation_id = correlation_id || SecureRandom.uuid_v7
    end

    def call
      transfer_ids = []
      StoredValueAccount::CUSTOMER_OWNED_TYPES.each do |account_type|
        source_account = open_account_for(@source, account_type)
        next unless source_account

        if source_account.balance_cents.zero?
          source_account.close_zero!
          next
        end

        survivor_account = StoredValue::EnsureCustomerAccount.call(
          customer: @survivor,
          account_type: account_type
        )
        transfer = StoredValue::Transfer.call(
          from_account: source_account,
          to_account: survivor_account,
          amount_cents: source_account.balance_cents,
          transfer_type: "customer_merge",
          performed_by: @actor,
          store: @store,
          source_id: @source.id,
          idempotency_key: SecureRandom.uuid_v7,
          merge_idempotency_operation: @merge_idempotency_operation,
          correlation_id: @correlation_id
        )
        transfer_ids << transfer.id
      end

      GiftCard.where(customer_id: @source.id).order(:id).each do |card|
        card.update!(customer: @survivor)
      end
      transfer_ids
    end

    private

    def open_account_for(customer, account_type)
      StoredValueAccount.where(customer_id: customer.id, account_type: account_type)
                        .where.not(status: "closed").order(:id).first
    end
  end
end
