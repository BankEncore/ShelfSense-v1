# frozen_string_literal: true

module Pos
  class TransactionsController < BaseController
    def index
      prepare_inquiry_shell!(surface: :transaction_history)
      @search = Pos::CompletedTransactionSearch.call(
        store: current_store,
        transaction_reference: params[:transaction_reference],
        register_id: params[:filter_register_id],
        receipt_sequence: params[:receipt_sequence],
        business_date: params[:business_date],
        page: params[:page]
      )
      @registers = current_store.registers.order(:register_number)
    end

    def show
      prepare_inquiry_shell!(surface: :transaction_history)
      @transaction = PosTransaction.completed
                                   .includes(
                                     :post_void_of,
                                     :post_void,
                                     :pos_controlled_actions,
                                     :customer,
                                     pos_transaction_lines: [
                                       :pos_line_tax_components,
                                       :pos_controlled_actions,
                                       { original_transaction_line: :pos_transaction },
                                       { post_void_source_line: :pos_transaction }
                                     ]
                                   )
                                   .find_by!(id: params[:id], store_id: current_store.id)
      @tenders = @transaction.pos_tenders.ordered.to_a
      @lines = @transaction.pos_transaction_lines.to_a
      @sale_lines = @lines.select { |line| line.sale? && !line.post_void_generated? }
      @summaries = Pos::Returnability.summary_for(@sale_lines)
      @post_void_reversal = @transaction.post_void
      @post_void_eligible = Pos::PostVoidEligibility.eligible?(@transaction)
      @returnable = @post_void_reversal.nil? && !@transaction.post_void? &&
                    @summaries.values.any? { |summary| summary.remaining_quantity.positive? }
    end
  end
end
