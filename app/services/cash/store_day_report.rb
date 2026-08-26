# frozen_string_literal: true

module Cash
  class StoreDayReport
    SessionRow = Struct.new(
      :session, :register_label, :cashier_name, :closer_name, :manager_assisted,
      :opening_float_cents, :cash_payment_cents, :cash_refund_cents, :gift_card_cash_out_cents,
      :expected_cents, :counted_cents, :variance_cents, :open, keyword_init: true
    )
    ReasonRow = Struct.new(:reason_code, :reason_name, :amount_cents, :count, keyword_init: true)
    DepositRow = Struct.new(:deposit, :reversed, keyword_init: true)

    def self.for(store:, business_date:)
      new(store: store, business_date: business_date)
    end

    def initialize(store:, business_date:)
      @store = store
      @business_date = business_date
    end

    def incomplete?
      sessions.any?(&:open)
    end

    def sessions_closed?
      sessions.any? && sessions.none?(&:open)
    end

    def safe_reconciled?
      accepted_safe_counts.exists?
    end

    def deposit_prepared?
      deposits.any?
    end

    def status_labels
      labels = []
      labels << "incomplete" if incomplete?
      labels << "sessions closed" if sessions_closed?
      labels << "safe reconciled" if safe_reconciled?
      labels << "deposit prepared" if deposit_prepared?
      labels.presence || [ "no cash activity" ]
    end

    def sessions
      @sessions ||= session_records.map { |session| session_row(session) }
    end

    def paid_ins
      @paid_ins ||= reason_rows(CashPaidIn.where(pos_session_id: session_ids))
    end

    def paid_outs
      @paid_outs ||= reason_rows(CashPaidOut.where(pos_session_id: session_ids))
    end

    def drop_cents
      session_transfers("drop")
    end

    def replenishment_cents
      session_transfers("replenishment")
    end

    def latest_safe_count
      accepted_safe_counts.order(created_at: :desc).first
    end

    def safe_expected_cents
      latest_safe_count&.expected_cents_snapshot
    end

    def safe_counted_cents
      latest_safe_count&.total_cents
    end

    def safe_variance_cents
      return if latest_safe_count.blank?

      latest_safe_count.total_cents - latest_safe_count.expected_cents_snapshot
    end

    def retained_cents
      Locations.safe_for!(@store).expected_balance_cents
    end

    def dit_balance_cents
      Locations.deposit_in_transit_for!(@store).expected_balance_cents
    end

    def deposits
      @deposits ||= CashDeposit.where(store: @store, business_date: @business_date)
                               .includes(:cash_operation)
                               .order(:deposit_number)
                               .map { |deposit| DepositRow.new(deposit: deposit, reversed: deposit.reversed?) }
    end

    def reversals
      @reversals ||= CashOperation.where(store: @store, business_date: @business_date, operation_type: "reverse")
                                  .order(:occurred_at)
    end

    def open_sessions
      sessions.select(&:open)
    end

    private

    def session_records
      @session_records ||= PosSession.joins(:reporting_period)
                                     .where(store_id: @store.id, pos_reporting_periods: { business_date: @business_date })
                                     .includes(:register, :cashier_user, :closed_by_user, :reporting_period)
                                     .order(:opened_at)
                                     .to_a
    end

    def session_ids
      session_records.map(&:id)
    end

    def session_row(session)
      totals = Pos::SessionTotals.for(session)
      SessionRow.new(
        session: session,
        register_label: session.register.admin_label,
        cashier_name: session.cashier_user.display_name,
        closer_name: session.closed_by_user&.display_name,
        manager_assisted: session.closed? && session.closed_by_user_id.present? &&
          session.closed_by_user_id != session.cashier_user_id,
        opening_float_cents: session.opening_float_cents,
        cash_payment_cents: totals.cash_payment_cents,
        cash_refund_cents: totals.cash_refund_cents,
        gift_card_cash_out_cents: totals.gift_card_cash_out_cents,
        expected_cents: session.closed? ? session.closing_expected_cash_cents : totals.expected_cash_cents,
        counted_cents: session.closing_count_cents,
        variance_cents: session.closing_variance_cents,
        open: session.open?
      )
    end

    def reason_rows(relation)
      relation.group(:reason_code, :reason_name_snapshot)
              .pluck(:reason_code, :reason_name_snapshot, Arel.sql("SUM(amount_cents)"), Arel.sql("COUNT(*)"))
              .map { |code, name, amount, count|
                ReasonRow.new(reason_code: code, reason_name: name, amount_cents: amount.to_i, count: count)
              }
    end

    def session_transfers(type)
      CashTransfer.where(transfer_type: type)
                  .joins(:cash_operation)
                  .where(cash_operations: { store_id: @store.id, business_date: @business_date })
                  .sum(:amount_cents)
    end

    def accepted_safe_counts
      CashCount.where(
        purpose: "safe_reconciliation",
        status: "accepted",
        business_date: @business_date,
        cash_location_id: Locations.safe_for!(@store).id
      )
    end
  end
end
