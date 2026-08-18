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
      completed_transactions.sum(:total_cents)
    end

    def cash_tender_cents
      category_payment_cents("cash")
    end

    def card_tender_cents
      category_payment_cents("card")
    end

    def check_tender_cents
      category_payment_cents("check")
    end

    def other_tender_cents
      category_payment_cents("other")
    end

    def expected_cash_cents
      return @session.closing_expected_cash_cents if @session.closed?

      @session.opening_float_cents + cash_tender_cents
    end

    def closing_count_cents
      @session.closing_count_cents
    end

    def closing_variance_cents
      @session.closing_variance_cents
    end

    private

    def category_payment_cents(category)
      PosTender.joins(:pos_transaction)
               .where(pos_transactions: { pos_session_id: @session.id, status: "completed" })
               .where(behavioral_category: category, direction: "payment")
               .sum(:amount_cents)
    end

    def completed_transactions
      @session.pos_transactions.completed
    end
  end
end
