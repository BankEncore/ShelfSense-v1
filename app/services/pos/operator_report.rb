# frozen_string_literal: true

module Pos
  # P13 report presenter over SessionTotals / PeriodTotals.
  # Formats authoritative domain results; does not recalculate commercial totals.
  class OperatorReport
    Group = Struct.new(:title, :rows, keyword_init: true)
    Row = Struct.new(:label, :cents, :format, keyword_init: true)

    SESSION_KINDS = %i[x session].freeze
    PERIOD_KINDS = %i[z_current z_finalized].freeze

    def self.session(totals:, session:, kind:, include_expected_cash: true)
      resolved = kind.to_sym
      raise ArgumentError, "unknown session report kind: #{kind}" unless SESSION_KINDS.include?(resolved)

      new(
        kind: resolved,
        totals: totals,
        session: session,
        include_expected_cash: include_expected_cash
      ).groups
    end

    def self.period(period:, include_expected_cash: true)
      totals = Pos::PeriodTotals.for(period)
      kind = period.finalized? ? :z_finalized : :z_current
      new(
        kind: kind,
        totals: totals,
        period: period,
        include_expected_cash: include_expected_cash
      ).groups
    end

    def initialize(kind:, totals:, session: nil, period: nil, include_expected_cash: true)
      @kind = kind.to_sym
      @totals = totals
      @session = session
      @period = period
      @include_expected_cash = include_expected_cash
    end

    def groups
      [
        sales_group,
        stored_value_group,
        returns_group,
        post_void_group,
        net_group,
        tenders_group,
        cash_group
      ].reject { |group| group.rows.empty? }
    end

    private

    def sales_group
      Group.new(title: "Sales", rows: compact_rows([
        count_row("Transactions", transaction_count),
        money_row("Gross sales", @totals.subtotal_cents),
        money_row("Sales discount", @totals.discount_cents),
        money_row("Sales tax", @totals.tax_cents),
        money_row("Sales total", @totals.total_cents)
      ]))
    end

    def stored_value_group
      rows = [
        money_row("Gift-card issuance", @totals.stored_value_issuance_cents),
        money_row("Stored-value payments", @totals.stored_value_payment_cents),
        money_row("Stored-value refunds", @totals.stored_value_refund_cents)
      ]

      if fine_stored_value_available?
        rows.concat([
          money_row("Store-credit payments", @totals.store_credit_payment_cents),
          money_row("Gift-card payments", @totals.gift_card_payment_cents),
          money_row("Refund to original gift card", @totals.gift_card_existing_refund_cents),
          money_row("Refund to new gift card", @totals.gift_card_new_refund_cents),
          money_row("Refund to store credit", @totals.store_credit_refund_destination_cents),
          count_row("Gift-card cash-outs", @totals.gift_card_cash_out_count)
        ])
      end

      rows.concat([
        money_row("Gift-card cash-outs", @totals.gift_card_cash_out_cents),
        money_row("Gift-card cash-out reversals", @totals.gift_card_cash_out_reversal_cents)
      ])

      Group.new(title: "Stored value", rows: compact_rows(rows))
    end

    def returns_group
      Group.new(title: "Returns", rows: compact_rows([
        money_row("Return subtotal", @totals.return_subtotal_cents),
        money_row("Return discount reversal", @totals.return_discount_cents),
        money_row("Return tax reversal", @totals.return_tax_cents),
        money_row("Returns total", @totals.return_total_cents)
      ]))
    end

    def post_void_group
      Group.new(title: "Post-void", rows: compact_rows([
        signed_row("Post-void adjustments", @totals.post_void_net_cents)
      ]))
    end

    def net_group
      Group.new(title: "Net", rows: compact_rows([
        signed_row("Net", @totals.net_cents)
      ]))
    end

    def tenders_group
      Group.new(title: "Tenders", rows: compact_rows([
        money_row("Cash payments", @totals.cash_payment_cents),
        money_row("Cash refunds", @totals.cash_refund_cents),
        money_row("Card payments", @totals.card_payment_cents),
        money_row("Card refunds", @totals.card_refund_cents),
        money_row("Check payments", @totals.check_payment_cents),
        money_row("Check refunds", @totals.check_refund_cents),
        money_row("Other payments", @totals.other_payment_cents),
        money_row("Other refunds", @totals.other_refund_cents)
      ]))
    end

    def cash_group
      Group.new(title: "Cash custody", rows: compact_rows(cash_rows))
    end

    def cash_rows
      case @kind
      when :x
        x_cash_rows
      when :session
        session_cash_rows
      when :z_current
        z_current_cash_rows
      when :z_finalized
        z_finalized_cash_rows
      else
        []
      end
    end

    def x_cash_rows
      rows = [
        money_row("Opening float", @session.opening_float_cents),
        money_row("Cash payments", @totals.cash_payment_cents),
        money_row("Cash refunds", @totals.cash_refund_cents),
        money_row("Gift-card cash-outs", @totals.gift_card_cash_out_cents),
        money_row("Gift-card cash-out reversals", @totals.gift_card_cash_out_reversal_cents)
      ]
      rows.concat(operational_cash_component_rows)
      rows << signed_row("Non-sale cash", @totals.cash_movement_cents)
      rows << signed_row("Expected Cash", @totals.expected_cash_cents) if @include_expected_cash
      rows
    end

    def session_cash_rows
      rows = [
        money_row("Opening float", @session.opening_float_cents),
        money_row("Cash payments", @totals.cash_payment_cents),
        money_row("Cash refunds", @totals.cash_refund_cents),
        money_row("Gift-card cash-outs", @totals.gift_card_cash_out_cents),
        money_row("Gift-card cash-out reversals", @totals.gift_card_cash_out_reversal_cents)
      ]
      rows.concat(operational_cash_component_rows)
      rows << money_row("Counted Cash", @session.closing_count_cents)
      if @include_expected_cash
        rows << signed_row("Expected closing Cash", @session.closing_expected_cash_cents)
        rows << signed_row("Variance", @session.closing_variance_cents)
      end
      rows
    end

    def z_current_cash_rows
      rows = [
        count_row("Sessions", @totals.session_count),
        money_row("Opening floats total", @totals.opening_float_cents_sum),
        money_row("Cash payments", @totals.cash_payment_cents),
        money_row("Cash refunds", @totals.cash_refund_cents),
        money_row("Gift-card cash-outs", @totals.gift_card_cash_out_cents),
        money_row("Gift-card cash-out reversals", @totals.gift_card_cash_out_reversal_cents)
      ]
      rows.concat(operational_cash_component_rows)
      if @include_expected_cash
        rows << signed_row("Expected closing Cash", @totals.closing_expected_cash_cents_sum)
        rows << money_row("Counted closing Cash", @totals.closing_count_cents_sum)
        rows << signed_row("Closing variance", @totals.closing_variance_cents_sum)
      else
        rows << money_row("Counted closing Cash", @totals.closing_count_cents_sum)
      end
      rows
    end

    def z_finalized_cash_rows
      rows = [
        count_row("Sessions", @totals.session_count),
        money_row("Opening floats total", @totals.opening_float_cents_sum),
        money_row("Cash payments", @totals.cash_payment_cents),
        money_row("Cash refunds", @totals.cash_refund_cents),
        money_row("Gift-card cash-outs", @totals.gift_card_cash_out_cents),
        money_row("Gift-card cash-out reversals", @totals.gift_card_cash_out_reversal_cents)
      ]
      if @include_expected_cash
        rows << signed_row("Expected closing Cash", @totals.closing_expected_cash_cents_sum)
        rows << money_row("Counted closing Cash", @totals.closing_count_cents_sum)
        rows << signed_row("Closing variance", @totals.closing_variance_cents_sum)
      else
        rows << money_row("Counted closing Cash", @totals.closing_count_cents_sum)
      end
      rows
    end

    def operational_cash_component_rows
      return [] unless operational_cash_components_available?

      [
        signed_row("Paid-in", @totals.paid_in_cents),
        signed_row("Paid-out", @totals.paid_out_cents),
        signed_row("Drops", @totals.drop_cents),
        signed_row("Replenishments", @totals.replenishment_cents),
        signed_row("Cash-operation reversals", @totals.cash_operation_reversal_cents)
      ]
    end

    def fine_stored_value_available?
      !finalized_period?
    end

    def operational_cash_components_available?
      !finalized_period?
    end

    def finalized_period?
      @kind == :z_finalized
    end

    def period_surface?
      PERIOD_KINDS.include?(@kind)
    end

    def transaction_count
      if period_surface?
        @totals.transaction_count
      else
        @totals.completed_transaction_count
      end
    end

    def compact_rows(rows)
      rows.compact
    end

    def money_row(label, cents)
      if cents.nil?
        # Finalized Z may still list snapshot columns that predate capture ("not captured").
        return Row.new(label: label, cents: nil, format: :optional_money) if finalized_period?

        return
      end

      Row.new(label: label, cents: cents, format: :money)
    end

    def signed_row(label, cents)
      if cents.nil?
        return Row.new(label: label, cents: nil, format: :optional_signed) if finalized_period?

        return
      end

      Row.new(label: label, cents: cents, format: :signed)
    end

    def count_row(label, value)
      return if value.nil?

      Row.new(label: label, cents: value, format: :count)
    end
  end
end
