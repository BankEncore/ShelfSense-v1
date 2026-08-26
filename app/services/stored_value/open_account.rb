# frozen_string_literal: true

module StoredValue
  class OpenAccount
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(account_type:, customer: nil, opened_at: Time.current)
      @account_type = account_type.to_s
      @customer = customer
      @opened_at = opened_at
    end

    def call
      raise Error, "account type is required" if @account_type.blank?
      if StoredValueAccount::CUSTOMER_OWNED_TYPES.include?(@account_type)
        raise Error, "customer is required" if @customer.blank?
        raise Error, "customer must be canonical" unless @customer.canonical?
        raise Error, "inactive customers cannot receive new credit" unless @customer.active?
      end

      currency_code = SystemSettings.current.base_currency_code
      StoredValueAccount.create!(
        account_type: @account_type,
        customer: @customer,
        currency_code: currency_code,
        balance_cents: 0,
        status: "active",
        opened_at: @opened_at
      )
    end
  end
end
