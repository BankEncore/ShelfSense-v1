# frozen_string_literal: true

module Pos
  class CompletedTransactionsController < BaseController
    def show
      @transaction = PosTransaction.find(params[:id])
      raise ActiveRecord::RecordNotFound unless @transaction.completed?

      Pos::Support.authorize!(current_user, @transaction.store)
      Pos::Support.require_transaction_cashier!(current_user, @transaction)
      @register = @transaction.register
      @session_record = @transaction.pos_session
      @period = @transaction.reporting_period
      @tender = @transaction.pos_tenders.find_by(tender_type: "cash")
      session[:pos_register_id] = @register.id
    rescue Pos::Denied
      raise ActiveRecord::RecordNotFound
    end
  end
end
