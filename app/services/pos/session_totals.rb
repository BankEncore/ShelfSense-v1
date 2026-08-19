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
      completed_transactions.sum(:subtotal_cents)
    end

    def discount_cents
      completed_transactions.sum(:discount_cents)
    end

    def tax_cents
      completed_transactions.sum(:tax_cents)
    end

    def total_cents
      subtotal_cents - discount_cents + tax_cents
    end

    def return_subtotal_cents
      completed_transactions.sum(:return_subtotal_cents)
    end

    def return_discount_cents
      completed_transactions.sum(:return_discount_cents)
    end

    def return_tax_cents
      completed_transactions.sum(:return_tax_cents)
    end

    def return_total_cents
      completed_transactions.sum(:return_total_cents)
    end

    def net_cents
      completed_transactions.sum(:signed_net_cents)
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

      @session.opening_float_cents + cash_payment_cents - cash_refund_cents
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

    def completed_transactions
      @session.pos_transactions.completed
    end
  end
end
