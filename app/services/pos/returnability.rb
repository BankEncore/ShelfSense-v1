# frozen_string_literal: true

module Pos
  class Returnability
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
  end
end
