# frozen_string_literal: true

module Pos
  # Detects working stored-value tenders/refund destinations that financially
  # depend on the transaction customer (Slice 7B.1).
  module CustomerDependency
    DEPENDENT_ACCOUNT_TYPES = %w[store_credit trade_credit].freeze
    REFUSAL_MESSAGE =
      "Remove the customer-dependent stored-value tender or Return to Sale before changing or clearing the customer.".freeze

    module_function

    def dependent_working_stored_value?(transaction)
      customer_id = transaction.customer_id
      return false if customer_id.blank?

      transaction.pos_tenders.includes(:stored_value_tender_detail, stored_value_tender_detail: :stored_value_account).any? do |tender|
        dependent_tender?(tender, customer_id)
      end
    end

    def refuse_customer_change!(transaction)
      return unless dependent_working_stored_value?(transaction)

      raise Pos::Error, REFUSAL_MESSAGE
    end

    def dependent_tender?(tender, customer_id)
      detail = tender.stored_value_tender_detail
      return false if detail.blank?

      return true if detail.customer_store_credit?

      account = detail.stored_value_account
      return false if account.blank?
      return false unless DEPENDENT_ACCOUNT_TYPES.include?(account.account_type)
      return false unless account.customer_id == customer_id

      true
    end
  end
end
