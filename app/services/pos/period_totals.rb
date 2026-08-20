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
      snapshot_or(:finalized_subtotal_cents) { commercial_transactions.sum(:subtotal_cents) }
    end

    def discount_cents
      snapshot_or(:finalized_discount_cents) { commercial_transactions.sum(:discount_cents) }
    end

    def tax_cents
      snapshot_or(:finalized_tax_cents) { commercial_transactions.sum(:tax_cents) }
    end

    def total_cents
      snapshot_or(:finalized_total_cents) { subtotal_cents - discount_cents + tax_cents }
    end

    def return_subtotal_cents
      snapshot_or(:finalized_return_subtotal_cents) { commercial_transactions.sum(:return_subtotal_cents) }
    end

    def return_discount_cents
      snapshot_or(:finalized_return_discount_cents) { commercial_transactions.sum(:return_discount_cents) }
    end

    def return_tax_cents
      snapshot_or(:finalized_return_tax_cents) { commercial_transactions.sum(:return_tax_cents) }
    end

    def return_total_cents
      snapshot_or(:finalized_return_total_cents) { commercial_transactions.sum(:return_total_cents) }
    end

    def net_cents
      snapshot_or(:finalized_net_cents) { completed_transactions.sum(:signed_net_cents) }
    end

    def post_void_transaction_count
      snapshot_or(:finalized_post_void_transaction_count) { post_void_transactions.count }
    end

    def post_void_merchandise_cents
      snapshot_or(:finalized_post_void_merchandise_cents) do
        signed_post_void_sum("subtotal_cents - return_subtotal_cents")
      end
    end

    def post_void_discount_cents
      snapshot_or(:finalized_post_void_discount_cents) do
        signed_post_void_sum("discount_cents - return_discount_cents")
      end
    end

    def post_void_tax_cents
      snapshot_or(:finalized_post_void_tax_cents) do
        signed_post_void_sum("tax_cents - return_tax_cents")
      end
    end

    def post_void_net_cents
      snapshot_or(:finalized_post_void_net_cents) { post_void_transactions.sum(:signed_net_cents) }
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

    def cash_refund_cents
      snapshot_or(:finalized_cash_refund_cents) { category_refund_cents("cash") }
    end

    def card_refund_cents
      snapshot_or(:finalized_card_refund_cents) { category_refund_cents("card") }
    end

    def check_refund_cents
      snapshot_or(:finalized_check_refund_cents) { category_refund_cents("check") }
    end

    def other_refund_cents
      snapshot_or(:finalized_other_refund_cents) { category_refund_cents("other") }
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
        finalized_discount_cents: discount_cents,
        finalized_tax_cents: tax_cents,
        finalized_total_cents: total_cents,
        finalized_return_subtotal_cents: return_subtotal_cents,
        finalized_return_discount_cents: return_discount_cents,
        finalized_return_tax_cents: return_tax_cents,
        finalized_return_total_cents: return_total_cents,
        finalized_net_cents: net_cents,
        finalized_cash_payment_cents: cash_payment_cents,
        finalized_card_payment_cents: card_payment_cents,
        finalized_check_payment_cents: check_payment_cents,
        finalized_other_payment_cents: other_payment_cents,
        finalized_cash_refund_cents: cash_refund_cents,
        finalized_card_refund_cents: card_refund_cents,
        finalized_check_refund_cents: check_refund_cents,
        finalized_other_refund_cents: other_refund_cents,
        finalized_post_void_transaction_count: post_void_transaction_count,
        finalized_post_void_merchandise_cents: post_void_merchandise_cents,
        finalized_post_void_discount_cents: post_void_discount_cents,
        finalized_post_void_tax_cents: post_void_tax_cents,
        finalized_post_void_net_cents: post_void_net_cents,
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
      category_tender_cents(category, "payment")
    end

    def category_refund_cents(category)
      category_tender_cents(category, "refund")
    end

    def category_tender_cents(category, direction)
      PosTender.joins(:pos_transaction)
               .where(pos_transactions: { reporting_period_id: @period.id, status: "completed" })
               .where(behavioral_category: category, direction: direction)
               .sum(:amount_cents)
    end

    def completed_transactions
      @period.pos_transactions.completed
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

    def closed_sessions
      @period.pos_sessions.closed
    end
  end
end
