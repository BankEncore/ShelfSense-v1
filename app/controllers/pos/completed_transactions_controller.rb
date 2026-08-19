# frozen_string_literal: true

module Pos
  class CompletedTransactionsController < BaseController
    def show
      @transaction = PosTransaction.find_by!(id: params[:id], store_id: current_store.id)
      raise ActiveRecord::RecordNotFound unless @transaction.completed?

      Pos::Support.authorize!(current_user, @transaction.store)
      Pos::Support.require_transaction_cashier!(current_user, @transaction)
      @register = @transaction.register
      @session_record = @transaction.pos_session
      @period = @transaction.reporting_period
      @tenders = @transaction.pos_tenders.ordered
      @tender = @tenders.find { |tender| tender.cash? && tender.direction == "payment" }
      @transaction.pos_transaction_lines.includes(original_transaction_line: :pos_transaction).load
      session[:pos_register_id] = @register.id
    rescue Pos::Denied
      raise ActiveRecord::RecordNotFound
    end
  end
end
