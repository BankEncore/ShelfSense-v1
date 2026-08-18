# frozen_string_literal: true

module Pos
  class PeriodTotals
    def self.for(period)
      new(period)
    end

    def initialize(period)
      @period = period
    end

    def transaction_count
      snapshot_or(:finalized_transaction_count) { completed_transactions.count }
    end

    def subtotal_cents
      snapshot_or(:finalized_subtotal_cents) { completed_transactions.sum(:subtotal_cents) }
    end

    def tax_cents
      snapshot_or(:finalized_tax_cents) { completed_transactions.sum(:tax_cents) }
    end

    def total_cents
      snapshot_or(:finalized_total_cents) { completed_transactions.sum(:total_cents) }
    end

    def cash_payment_cents
      snapshot_or(:finalized_cash_payment_cents) { category_payment_cents("cash") }
    end

    def card_payment_cents
      snapshot_or(:finalized_card_payment_cents) { category_payment_cents("card") }
    end

    def check_payment_cents
      snapshot_or(:finalized_check_payment_cents) { category_payment_cents("check") }
    end

    def other_payment_cents
      snapshot_or(:finalized_other_payment_cents) { category_payment_cents("other") }
    end

    def session_count
      snapshot_or(:finalized_session_count) { closed_sessions.count }
    end

    def opening_float_cents_sum
      snapshot_or(:finalized_opening_float_cents_sum) { closed_sessions.sum(:opening_float_cents) }
    end

    def closing_expected_cash_cents_sum
      snapshot_or(:finalized_closing_expected_cash_cents_sum) { closed_sessions.sum(:closing_expected_cash_cents) }
    end

    def closing_count_cents_sum
      snapshot_or(:finalized_closing_count_cents_sum) { closed_sessions.sum(:closing_count_cents) }
    end

    def closing_variance_cents_sum
      snapshot_or(:finalized_closing_variance_cents_sum) { closed_sessions.sum(:closing_variance_cents) }
    end

    def snapshot
      {
        finalized_transaction_count: transaction_count,
        finalized_subtotal_cents: subtotal_cents,
        finalized_tax_cents: tax_cents,
        finalized_total_cents: total_cents,
        finalized_cash_payment_cents: cash_payment_cents,
        finalized_card_payment_cents: card_payment_cents,
        finalized_check_payment_cents: check_payment_cents,
        finalized_other_payment_cents: other_payment_cents,
        finalized_session_count: session_count,
        finalized_opening_float_cents_sum: opening_float_cents_sum,
        finalized_closing_expected_cash_cents_sum: closing_expected_cash_cents_sum,
        finalized_closing_count_cents_sum: closing_count_cents_sum,
        finalized_closing_variance_cents_sum: closing_variance_cents_sum
      }
    end

    private

    def snapshot_or(column)
      return @period.public_send(column) if @period.finalized?

      yield
    end

    def category_payment_cents(category)
      PosTender.joins(:pos_transaction)
               .where(pos_transactions: { reporting_period_id: @period.id, status: "completed" })
               .where(behavioral_category: category, direction: "payment")
               .sum(:amount_cents)
    end

    def completed_transactions
      @period.pos_transactions.completed
    end

    def closed_sessions
      @period.pos_sessions.closed
    end
  end
end
