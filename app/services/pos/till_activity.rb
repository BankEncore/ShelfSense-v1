# frozen_string_literal: true

module Pos
  # Authoritative Till Activity projection for a single PosSession (Slice 6B S17).
  # Custody movements only — CashOperation (+ transfers) and GiftCardCashOut.
  class TillActivity
    PER_PAGE = 50

    Row = Data.define(
      :id, :source, :occurred_at, :label, :session_effect_cents, :performed_by_name,
      :approver_name, :status, :reversal_of_id, :reversed_by_id, :reference
    )
    Result = Data.define(:session, :rows, :page, :total_count, :total_pages)

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(session:, page: 1)
      @session = session
      @page = [ Integer(page), 1 ].max
    rescue ArgumentError, TypeError
      @session = session
      @page = 1
    end

    def call
      rows = (cash_operation_rows + gift_card_cash_out_rows).sort_by { |row| [ -row.occurred_at.to_r, row.source, row.id ] }
      total_count = rows.size
      total_pages = [ (total_count.to_f / PER_PAGE).ceil, 1 ].max
      page = [ @page, total_pages ].min
      slice = rows.slice((page - 1) * PER_PAGE, PER_PAGE) || []

      Result.new(
        session: @session,
        rows: slice,
        page: page,
        total_count: total_count,
        total_pages: total_pages
      )
    end

    private

    def cash_operation_rows
      ops = CashOperation.where(store_id: @session.store_id, pos_session_id: @session.id)
                         .includes(:performed_by, :approved_by, :cash_transfer, :reversed_by, :reversal_of, :cash_entries)
                         .to_a
      # Also include operations that touch the session only via cash_entries
      entry_op_ids = CashEntry.where(pos_session_id: @session.id).distinct.pluck(:cash_operation_id)
      extra = CashOperation.where(id: entry_op_ids - ops.map(&:id))
                           .includes(:performed_by, :approved_by, :cash_transfer, :reversed_by, :reversal_of, :cash_entries)
                           .to_a
      (ops + extra).filter_map { |operation| row_for_cash_operation(operation) }
    end

    def row_for_cash_operation(operation)
      transfer = operation.cash_transfer
      return nil if transfer && transfer.transfer_type == "session_close"
      return nil if transfer && transfer.transfer_type == "deposit"

      effect = operation.cash_entries.select { |entry| entry.pos_session_id == @session.id }.sum(&:amount_cents)
      Row.new(
        id: operation.id,
        source: "cash_operation",
        occurred_at: operation.occurred_at,
        label: cash_operation_label(operation, transfer),
        session_effect_cents: effect,
        performed_by_name: operation.performed_by.display_name,
        approver_name: operation.approved_by&.display_name,
        status: operation.reversed? ? "reversed" : (operation.reverse? ? "reversal" : "posted"),
        reversal_of_id: operation.reversal_of_id,
        reversed_by_id: operation.reversed_by&.id,
        reference: operation.id
      )
    end

    def cash_operation_label(operation, transfer)
      if transfer
        case transfer.transfer_type
        when "opening_float" then "Opening float"
        when "drop" then "Cash drop"
        when "replenishment" then "Replenishment"
        else transfer.transfer_type.humanize
        end
      elsif operation.reverse?
        "Reversal"
      else
        operation.operation_type.humanize
      end
    end

    def gift_card_cash_out_rows
      GiftCardCashOut.where(pos_session_id: @session.id)
                     .includes(:performed_by, :approved_by, :reversal_of, :reversed_by)
                     .map { |cash_out| row_for_gift_card_cash_out(cash_out) }
    end

    def row_for_gift_card_cash_out(cash_out)
      effect = cash_out.reversal? ? cash_out.amount_cents : -cash_out.amount_cents
      Row.new(
        id: cash_out.id,
        source: "gift_card_cash_out",
        occurred_at: cash_out.posted_at,
        label: cash_out.reversal? ? "Gift-card cash-out reversal" : "Gift-card cash-out",
        session_effect_cents: effect,
        performed_by_name: cash_out.performed_by.display_name,
        approver_name: cash_out.approved_by&.display_name,
        status: cash_out.reversed? ? "reversed" : (cash_out.reversal? ? "reversal" : "posted"),
        reversal_of_id: cash_out.reversal_of_id,
        reversed_by_id: cash_out.reversed_by&.id,
        reference: cash_out.id
      )
    end
  end
end
