# frozen_string_literal: true

module Pos
  class OperatorReport
    Group = Struct.new(:title, :rows, keyword_init: true)
    Row = Struct.new(:label, :cents, :format, keyword_init: true)

    def self.session(totals:, session:, kind:)
      new(kind: kind, totals: totals, session: session).groups
    end

    def self.period(period:)
      new(kind: :z, totals: Pos::PeriodTotals.for(period), period: period).groups
    end

    def initialize(kind:, totals:, session: nil, period: nil)
      @kind = kind
      @totals = totals
      @session = session
      @period = period
    end

    def groups
      [ sales_group, stored_value_group, returns_group, post_void_group, net_group, tenders_group, cash_group ]
    end

    private

    def stored_value_group
      Group.new(title: "Stored value", rows: [
        money_row("Gift-card issuance", @totals.stored_value_issuance_cents),
        money_row("Store-credit payments", @totals.store_credit_payment_cents),
        money_row("Trade-credit payments", @totals.trade_credit_payment_cents),
        money_row("Gift-card payments", @totals.gift_card_payment_cents),
        money_row("Refund to original gift card", @totals.gift_card_existing_refund_cents),
        money_row("Refund to new gift card", @totals.gift_card_new_refund_cents),
        money_row("Refund to store credit", @totals.store_credit_refund_destination_cents),
        count_row("Gift-card cash-outs", @totals.gift_card_cash_out_count),
        money_row("Gift-card cash-outs", @totals.gift_card_cash_out_cents),
        money_row("Gift-card cash-out reversals", @totals.gift_card_cash_out_reversal_cents)
      ])
    end

    def sales_group
      Group.new(title: "Sales", rows: [
        count_row("Transactions", transaction_count),
        money_row("Sales subtotal", @totals.subtotal_cents),
        money_row("Sales discount", @totals.discount_cents),
        money_row("Sales tax", @totals.tax_cents),
        money_row("Sales total", @totals.total_cents)
      ])
    end

    def returns_group
      Group.new(title: "Returns", rows: [
        money_row("Return subtotal", @totals.return_subtotal_cents),
        money_row("Return discount reversal", @totals.return_discount_cents),
        money_row("Return tax reversal", @totals.return_tax_cents),
        money_row("Returns total", @totals.return_total_cents)
      ])
    end

    def post_void_group
      Group.new(title: "Post-void", rows: [
        signed_row("Post-void adjustments", @totals.post_void_net_cents)
      ])
    end

    def net_group
      Group.new(title: "Net", rows: [
        signed_row("Net", @totals.net_cents)
      ])
    end

    def tenders_group
      Group.new(title: "Tenders", rows: [
        money_row("Cash payments", @totals.cash_payment_cents),
        money_row("Cash refunds", @totals.cash_refund_cents),
        money_row("Card payments", @totals.card_payment_cents),
        money_row("Card refunds", @totals.card_refund_cents),
        money_row("Check payments", @totals.check_payment_cents),
        money_row("Check refunds", @totals.check_refund_cents),
        money_row("Other payments", @totals.other_payment_cents),
        money_row("Other refunds", @totals.other_refund_cents)
      ])
    end

    def cash_group
      Group.new(title: "Cash custody", rows: cash_rows)
    end

    def cash_rows
      case @kind
      when :x
        [
          money_row("Opening float", @session.opening_float_cents),
          money_row("Cash payments", @totals.cash_payment_cents),
          money_row("Cash refunds", @totals.cash_refund_cents),
          money_row("Gift-card cash-outs", @totals.gift_card_cash_out_cents),
          money_row("Gift-card cash-out reversals", @totals.gift_card_cash_out_reversal_cents),
          signed_row("Expected Cash", @totals.expected_cash_cents)
        ]
      when :session
        [
          money_row("Opening float", @session.opening_float_cents),
          money_row("Cash payments", @totals.cash_payment_cents),
          money_row("Cash refunds", @totals.cash_refund_cents),
          money_row("Gift-card cash-outs", @totals.gift_card_cash_out_cents),
          money_row("Gift-card cash-out reversals", @totals.gift_card_cash_out_reversal_cents),
          signed_row("Expected closing Cash", @session.closing_expected_cash_cents),
          money_row("Counted Cash", @session.closing_count_cents),
          signed_row("Variance", @session.closing_variance_cents)
        ]
      else
        [
          count_row("Sessions", @totals.session_count),
          money_row("Opening floats total", @totals.opening_float_cents_sum),
          money_row("Cash payments", @totals.cash_payment_cents),
          money_row("Cash refunds", @totals.cash_refund_cents),
          money_row("Gift-card cash-outs", @totals.gift_card_cash_out_cents),
          money_row("Gift-card cash-out reversals", @totals.gift_card_cash_out_reversal_cents),
          signed_row("Expected closing Cash", @totals.closing_expected_cash_cents_sum),
          money_row("Counted closing Cash", @totals.closing_count_cents_sum),
          signed_row("Closing variance", @totals.closing_variance_cents_sum)
        ]
      end
    end

    def transaction_count
      if @kind == :z
        @period.finalized? ? @period.finalized_transaction_count : @totals.transaction_count
      else
        @totals.completed_transaction_count
      end
    end

    def money_row(label, cents)
      Row.new(label: label, cents: cents, format: z? ? :optional_money : :money)
    end

    def signed_row(label, cents)
      Row.new(label: label, cents: cents, format: z? ? :optional_signed : :signed)
    end

    def count_row(label, value)
      Row.new(label: label, cents: value, format: :count)
    end

    def z?
      @kind == :z
    end
  end
end
