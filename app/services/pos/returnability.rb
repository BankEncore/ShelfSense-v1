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
      scope = effective_completed_linked_returns(original_line.id)
      scope = scope.where.not(id: excluding_line_id) if excluding_line_id
      scope.sum(:quantity)
    end

    def self.remaining_quantity(original_line, excluding_line_id: nil)
      return 0 if post_voided_source?(original_line.pos_transaction_id)

      original_line.quantity - completed_returned_quantity(original_line, excluding_line_id: excluding_line_id)
    end

    def self.completed_linked_returns(original_line)
      effective_completed_linked_returns(original_line.id)
    end

    def self.effective_completed_linked_returns(original_line_ids)
      ids = Array(original_line_ids)
      PosTransactionLine.joins(:pos_transaction)
                        .where(original_transaction_line_id: ids, direction: "return")
                        .where(pos_transactions: { status: "completed" })
                        .where.not(pos_transaction_id: post_voided_transaction_ids)
    end

    def self.post_voided_source?(transaction_id)
      PosTransaction.completed.exists?(post_void_of_transaction_id: transaction_id)
    end

    def self.post_voided_transaction_ids
      PosTransaction.completed.where.not(post_void_of_transaction_id: nil).select(:post_void_of_transaction_id)
    end

    def self.summary_for(original_lines)
      lines = Array(original_lines)
      ids = lines.map(&:id)
      return {} if ids.empty?

      post_voided_ids = PosTransaction.completed
                                      .where(post_void_of_transaction_id: lines.map(&:pos_transaction_id).uniq)
                                      .pluck(:post_void_of_transaction_id)
                                      .to_set

      returned_quantities = effective_completed_linked_returns(ids)
                            .group(:original_transaction_line_id)
                            .sum(:quantity)
      completed_lines = effective_completed_linked_returns(ids)
                        .includes(:pos_transaction)
                        .order("pos_transactions.completed_at", "pos_transaction_lines.id")
                        .group_by(&:original_transaction_line_id)

      lines.each_with_object({}) do |line, summaries|
        sold = line.quantity
        if post_voided_ids.include?(line.pos_transaction_id)
          summaries[line.id] = Summary.new(
            sold_quantity: sold,
            completed_returned_quantity: 0,
            remaining_quantity: 0,
            completed_return_lines: []
          )
          next
        end

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
