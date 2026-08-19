# frozen_string_literal: true

module Pos
  class Returnability
    Summary = Struct.new(
      :sold_quantity,
      :completed_returned_quantity,
      :remaining_quantity,
      :completed_return_lines,
      keyword_init: true
    )

    def self.completed_returned_quantity(original_line, excluding_line_id: nil)
      scope = completed_linked_returns(original_line)
      scope = scope.where.not(id: excluding_line_id) if excluding_line_id
      scope.sum(:quantity)
    end

    def self.remaining_quantity(original_line, excluding_line_id: nil)
      original_line.quantity - completed_returned_quantity(original_line, excluding_line_id: excluding_line_id)
    end

    def self.completed_linked_returns(original_line)
      PosTransactionLine.joins(:pos_transaction)
                        .where(original_transaction_line_id: original_line.id, direction: "return")
                        .where(pos_transactions: { status: "completed" })
    end

    def self.summary_for(original_lines)
      lines = Array(original_lines)
      ids = lines.map(&:id)
      return {} if ids.empty?

      returned_quantities = PosTransactionLine.joins(:pos_transaction)
                                              .where(original_transaction_line_id: ids, direction: "return")
                                              .where(pos_transactions: { status: "completed" })
                                              .group(:original_transaction_line_id)
                                              .sum(:quantity)
      completed_lines = PosTransactionLine.joins(:pos_transaction)
                                          .where(original_transaction_line_id: ids, direction: "return")
                                          .where(pos_transactions: { status: "completed" })
                                          .includes(:pos_transaction)
                                          .order("pos_transactions.completed_at", "pos_transaction_lines.id")
                                          .group_by(&:original_transaction_line_id)

      lines.each_with_object({}) do |line, summaries|
        sold = line.quantity
        returned = returned_quantities[line.id] || returned_quantities[line.id.to_s] || 0
        summaries[line.id] = Summary.new(
          sold_quantity: sold,
          completed_returned_quantity: returned,
          remaining_quantity: sold - returned,
          completed_return_lines: completed_lines[line.id] || completed_lines[line.id.to_s] || []
        )
      end
    end
  end
end
