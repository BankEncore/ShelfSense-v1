# frozen_string_literal: true

module Pos
  class SessionTotals
    def self.for(session)
      new(session)
    end

    def initialize(session)
      @session = session
    end

    def completed_transaction_count
      completed_transactions.count
    end

    def subtotal_cents
      commercial_transactions.sum(:subtotal_cents)
    end

    def discount_cents
      commercial_transactions.sum(:discount_cents)
    end

    def tax_cents
      commercial_transactions.sum(:tax_cents)
    end

    def total_cents
      subtotal_cents - discount_cents + tax_cents
    end

    def return_subtotal_cents
      commercial_transactions.sum(:return_subtotal_cents)
    end

    def return_discount_cents
      commercial_transactions.sum(:return_discount_cents)
    end

    def return_tax_cents
      commercial_transactions.sum(:return_tax_cents)
    end

    def return_total_cents
      commercial_transactions.sum(:return_total_cents)
    end

    def net_cents
      completed_transactions.sum(:signed_net_cents)
    end

    def post_void_transaction_count
      post_void_transactions.count
    end

    def post_void_merchandise_cents
      signed_post_void_sum("subtotal_cents - return_subtotal_cents")
    end

    def post_void_discount_cents
      signed_post_void_sum("discount_cents - return_discount_cents")
    end

    def post_void_tax_cents
      signed_post_void_sum("tax_cents - return_tax_cents")
    end

    def post_void_net_cents
      post_void_transactions.sum(:signed_net_cents)
    end

    def cash_tender_cents
      cash_payment_cents
    end

    def cash_payment_cents
      category_payment_cents("cash")
    end

    def card_tender_cents
      card_payment_cents
    end

    def card_payment_cents
      category_payment_cents("card")
    end

    def check_tender_cents
      check_payment_cents
    end

    def check_payment_cents
      category_payment_cents("check")
    end

    def other_tender_cents
      other_payment_cents
    end

    def other_payment_cents
      category_payment_cents("other")
    end

    def cash_refund_cents
      category_refund_cents("cash")
    end

    def card_refund_cents
      category_refund_cents("card")
    end

    def check_refund_cents
      category_refund_cents("check")
    end

    def other_refund_cents
      category_refund_cents("other")
    end

    def expected_cash_cents
      return @session.closing_expected_cash_cents if @session.closed?

      @session.opening_float_cents + cash_payment_cents - cash_refund_cents -
        gift_card_cash_out_cents + gift_card_cash_out_reversal_cents +
        cash_movement_cents
    end

    def available_cash_cents
      expected_cash_cents
    end

    def stored_value_issuance_cents
      commercial_transactions.sum(:stored_value_issuance_cents)
    end

    def stored_value_payment_cents
      category_payment_cents("stored_value")
    end

    def stored_value_refund_cents
      category_refund_cents("stored_value")
    end

    def gift_card_cash_out_cents
      GiftCardCashOut.originals.where(pos_session_id: @session.id).sum(:amount_cents)
    end

    def gift_card_cash_out_reversal_cents
      GiftCardCashOut.reversals.where(pos_session_id: @session.id).sum(:amount_cents)
    end

    def cash_movement_cents
      paid = CashEntry.joins(:cash_operation)
                      .where(pos_session_id: @session.id)
                      .where(cash_operations: { operation_type: %w[paid_in paid_out] })
                      .sum(:amount_cents)
      transfers = CashEntry.joins(cash_operation: :cash_transfer)
                           .where(pos_session_id: @session.id)
                           .where(cash_transfers: { transfer_type: %w[drop replenishment] })
                           .sum(:amount_cents)
      paid + transfers
    end

    def gift_card_cash_out_count
      GiftCardCashOut.originals.where(pos_session_id: @session.id).count
    end

    def store_credit_payment_cents
      type_tender_cents("store_credit", "payment")
    end

    def trade_credit_payment_cents
      type_tender_cents("trade_credit", "payment")
    end

    def gift_card_payment_cents
      type_tender_cents("gift_card", "payment")
    end

    def gift_card_existing_refund_cents
      refund_destination_cents("existing_account", tender_type: "gift_card")
    end

    def gift_card_new_refund_cents
      refund_destination_cents("new_gift_card")
    end

    def store_credit_refund_destination_cents
      refund_destination_cents("customer_store_credit") +
        refund_destination_cents("existing_account", tender_type: "store_credit")
    end

    def closing_count_cents
      @session.closing_count_cents
    end

    def closing_variance_cents
      @session.closing_variance_cents
    end

    private

    def category_payment_cents(category)
      category_tender_cents(category, "payment")
    end

    def category_refund_cents(category)
      category_tender_cents(category, "refund")
    end

    def category_tender_cents(category, direction)
      PosTender.joins(:pos_transaction)
               .where(pos_transactions: { pos_session_id: @session.id, status: "completed" })
               .where(behavioral_category: category, direction: direction)
               .sum(:amount_cents)
    end

    def type_tender_cents(tender_type, direction)
      PosTender.joins(:pos_transaction)
               .where(pos_transactions: { pos_session_id: @session.id, status: "completed" })
               .where(tender_type: tender_type, direction: direction)
               .sum(:amount_cents)
    end

    def refund_destination_cents(destination_mode, tender_type: nil)
      relation = PosTender.joins(:pos_transaction, :stored_value_tender_detail)
                          .where(pos_transactions: { pos_session_id: @session.id, status: "completed" })
                          .where(direction: "refund")
                          .where(pos_stored_value_tender_details: { destination_mode: destination_mode })
      relation = relation.where(tender_type: tender_type) if tender_type
      relation.sum(:amount_cents)
    end

    def completed_transactions
      @session.pos_transactions.completed
    end

    def commercial_transactions
      completed_transactions.where(post_void_of_transaction_id: nil)
    end

    def post_void_transactions
      completed_transactions.where.not(post_void_of_transaction_id: nil)
    end

    def signed_post_void_sum(expression)
      post_void_transactions.sum(Arel.sql(expression)).to_i
    end
  end
end
