# frozen_string_literal: true

module Pos
  class TransactionsController < BaseController
    def index
      @search = Pos::CompletedTransactionSearch.call(
        store: current_store,
        transaction_reference: params[:transaction_reference],
        register_id: params[:register_id],
        receipt_sequence: params[:receipt_sequence],
        business_date: params[:business_date],
        page: params[:page]
      )
      @registers = current_store.registers.order(:register_number)
    end

    def show
      @transaction = PosTransaction.completed.find_by!(id: params[:id], store_id: current_store.id)
      @tenders = @transaction.pos_tenders.ordered.to_a
      @lines = @transaction.pos_transaction_lines.includes(:pos_line_tax_components, :pos_controlled_actions).to_a
    end
  end
end
