# frozen_string_literal: true

module Admin
  class CashSafesController < BaseController
    before_action -> { require_permission!("cash.initialize_safe") }
    before_action :ensure_store_selected

    def show
      @safe = Cash::Locations.safe_for!(current_store)
    end

    def new
      @safe = Cash::Locations.safe_for!(current_store)
      redirect_to admin_cash_safe_path, alert: "This store safe is already initialized." if @safe.initialized?
    end

    def create
      @safe = Cash::Locations.safe_for!(current_store)
      count_cents = Money::ParseCents.call(params[:count])
      raise Cash::Error, "count is required" if count_cents.nil?

      approver = Pos::AuthenticateApprover.call(
        username: params[:approver_username],
        password: params[:approver_password],
        store: current_store,
        action_type: "initialize_safe",
        performer: current_user,
        permission_key: "cash.approve_initialize_safe"
      )
      Cash::InitializeSafe.call(
        store: current_store,
        performed_by: current_user,
        approved_by: approver,
        count_cents: count_cents,
        notes: params[:notes],
        source_id: params[:source_id].presence || SecureRandom.uuid_v7,
        idempotency_key: params[:idempotency_key].presence || SecureRandom.uuid_v7
      )
      redirect_to admin_cash_safe_path, notice: "Store safe initialized."
    rescue Money::ParseCents::Error, Cash::Error, Pos::Denied => e
      @safe = Cash::Locations.safe_for!(current_store)
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
