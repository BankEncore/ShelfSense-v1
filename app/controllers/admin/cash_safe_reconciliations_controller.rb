# frozen_string_literal: true

module Admin
  class CashSafeReconciliationsController < BaseController
    before_action -> { require_permission!("cash.reconcile_safe") }
    before_action :ensure_store_selected

    def new
      @safe = Cash::Locations.safe_for!(current_store)
      unless @safe.initialized?
        redirect_to admin_cash_safe_path, alert: "Initialize the store safe before reconciling."
        return
      end

      Cash::ActivityReasons.seed!
      @count = Cash::SnapshotCount.start!(location: @safe, purpose: "safe_reconciliation")
      @can_view_expected = Authorization::PermissionEvaluator.allowed?(
        user: current_user, permission_key: "cash.view_expected_before_count", store: current_store
      )
      @variance_reasons = CashActivityReason.active.where(operation_kind: %w[over short]).order(:name)
    end

    def create
      @safe = Cash::Locations.safe_for!(current_store)
      start_count = CashCount.find(params.require(:cash_count_id))
      counted = Money::ParseCents.call(params[:count])
      raise Cash::Error, "count is required" if counted.nil?

      Cash::ReconcileSafe.call(
        store: current_store,
        actor: current_user,
        start_count: start_count,
        count_cents: counted,
        reason_code: params[:variance_reason_code],
        notes: params[:variance_notes],
        approver_username: params[:approver_username],
        approver_password: params[:approver_password],
        source_id: params[:source_id].presence || SecureRandom.uuid_v7,
        idempotency_key: params[:idempotency_key].presence || SecureRandom.uuid_v7
      )
      redirect_to admin_cash_safe_path, notice: "Safe count accepted."
    rescue Money::ParseCents::Error, Cash::Error, Pos::Denied, ActiveRecord::RecordNotFound => e
      @count = CashCount.find_by(id: params[:cash_count_id]) || Cash::SnapshotCount.start!(location: @safe, purpose: "safe_reconciliation")
      @can_view_expected = Authorization::PermissionEvaluator.allowed?(
        user: current_user, permission_key: "cash.view_expected_before_count", store: current_store
      )
      Cash::ActivityReasons.seed!
      @variance_reasons = CashActivityReason.active.where(operation_kind: %w[over short]).order(:name)
      @feedback = e.message
      render :new, status: :unprocessable_content
    end

    private

    def ensure_store_selected
      return if current_store

      redirect_to new_store_selection_path, alert: "Select a store."
    end
  end
end
