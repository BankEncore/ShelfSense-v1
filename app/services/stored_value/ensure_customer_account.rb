# frozen_string_literal: true

module StoredValue
  class EnsureCustomerAccount
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(customer:, account_type:)
      @customer = customer
      @account_type = account_type.to_s
    end

    def call
      raise Error, "unsupported account type" unless StoredValueAccount::CUSTOMER_OWNED_TYPES.include?(@account_type)

      existing = StoredValueAccount.where(customer_id: @customer.id, account_type: @account_type)
                                   .where.not(status: "closed").order(:id).first
      return existing if existing

      OpenAccount.call(account_type: @account_type, customer: @customer)
    end
  end
end
