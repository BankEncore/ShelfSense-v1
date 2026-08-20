# frozen_string_literal: true

module Pos
  class PostVoidEligibility
    def self.eligible?(source)
      new(source).eligible?
    end

    def initialize(source)
      @source = source
    end

    def eligible?
      return false unless @source.completed?
      return false if @source.post_void?
      return false if PosTransaction.completed.exists?(post_void_of_transaction_id: @source.id)

      sale_ids = @source.pos_transaction_lines.select(&:sale?).map(&:id)
      return true if sale_ids.empty?

      return false if Pos::Returnability.effective_completed_linked_returns(sale_ids).exists?

      working = PosTransactionLine.joins(:pos_transaction)
                                  .where(original_transaction_line_id: sale_ids, direction: "return")
                                  .where(pos_transactions: { status: "working" })
      !working.exists?
    end
  end
end
