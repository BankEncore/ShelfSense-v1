# frozen_string_literal: true

module Admin
  class CashDepositsController < BaseController
    before_action -> { require_permission!("cash.prepare_deposit") }
    before_action :ensure_store_selected

    def index
      @deposits = CashDeposit.where(store: current_store).includes(:cash_operation, :prepared_by).order(business_date: :desc, deposit_number: :desc)
      @dit = Cash::Locations.deposit_in_transit_for!(current_store)
    end

    def new
      @safe = Cash::Locations.safe_for!(current_store)
      unless @safe.initialized?
        redirect_to admin_cash_safe_path, alert: "Initialize the store safe before preparing a deposit."
        return
      end

      @count = Cash::SnapshotCount.start!(location: @safe, purpose: "deposit")
      @can_view_expected = Authorization::PermissionEvaluator.allowed?(
        user: current_user, permission_key: "cash.view_expected_before_count", store: current_store
      )
    end

    def create
      @safe = Cash::Locations.safe_for!(current_store)
      start_count = CashCount.find(params.require(:cash_count_id))
      amount = Money::ParseCents.call(params[:amount])
      raise Cash::Error, "amount is required" if amount.nil?

      deposit = Cash::PrepareDeposit.call(
        store: current_store,
        actor: current_user,
        start_count: start_count,
        amount_cents: amount,
        bag_reference: params[:bag_reference],
        source_id: params[:source_id].presence || SecureRandom.uuid_v7,
        idempotency_key: params[:idempotency_key].presence || SecureRandom.uuid_v7
      )
      redirect_to admin_cash_deposit_path(deposit), notice: "Deposit prepared."
    rescue Money::ParseCents::Error, Cash::Error, ActiveRecord::RecordNotFound => e
      @count = CashCount.find_by(id: params[:cash_count_id]) || Cash::SnapshotCount.start!(location: @safe, purpose: "deposit")
      @can_view_expected = Authorization::PermissionEvaluator.allowed?(
        user: current_user, permission_key: "cash.view_expected_before_count", store: current_store
      )
      @feedback = e.message
      render :new, status: :unprocessable_content
    end

    def show
      @deposit = CashDeposit.where(store: current_store).find(params[:id])
      @dit = Cash::Locations.deposit_in_transit_for!(current_store)
    end

    def reverse
      @deposit = CashDeposit.where(store: current_store).find(params[:id])
      unless Authorization::PermissionEvaluator.allowed?(
        user: current_user, permission_key: "cash.reverse", store: current_store
      )
        redirect_to admin_cash_deposit_path(@deposit), alert: "You are not authorized to reverse this deposit."
        return
      end

      Cash::Reverse.call(
        operation: @deposit.cash_operation,
        actor: current_user,
        reason_code: params[:reason_code].presence || "reverse",
        notes: params[:notes],
        source_id: params[:source_id].presence || SecureRandom.uuid_v7,
        idempotency_key: params[:idempotency_key].presence || SecureRandom.uuid_v7
      )
      redirect_to admin_cash_deposit_path(@deposit), notice: "Deposit reversed."
    rescue Cash::Error => e
      @dit = Cash::Locations.deposit_in_transit_for!(current_store)
      @feedback = e.message
      render :show, status: :unprocessable_content
    end

    private

    def ensure_store_selected
      return if current_store

      redirect_to new_store_selection_path, alert: "Select a store."
    end
  end
end
