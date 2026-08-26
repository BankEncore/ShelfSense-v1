# frozen_string_literal: true

module Admin
  class StoredValueTransfersController < BaseController
    before_action -> { require_permission!("stored_value.transfer") }

    def new
      @from_customer = Customer.find_by(id: params[:from_customer_id])
      @account_type = params[:account_type].presence_in(StoredValueAccount::CUSTOMER_OWNED_TYPES) || "store_credit"
    end

    def create
      from_customer = Customer.find(params.require(:from_customer_id))
      to_customer = Customer.find(params.require(:to_customer_id))
      account_type = params.require(:account_type).presence_in(StoredValueAccount::CUSTOMER_OWNED_TYPES)
      raise StoredValue::Error, "account type is required" if account_type.blank?

      transfer_type = params[:transfer_type].presence_in(%w[administrative account_consolidation]) || "administrative"
      from_account = open_customer_account(from_customer, account_type)
      raise StoredValue::Error, "source has no open #{account_type.humanize.downcase} account" if from_account.nil?

      if transfer_type == "account_consolidation" && from_account.balance_cents.zero?
        from_account.close_zero!
        redirect_to admin_customer_path(from_customer), notice: "Zero-balance source account closed. No transfer posted."
        return
      end

      amount_cents = if transfer_type == "account_consolidation"
        from_account.balance_cents
      else
        Money::ParseCents.call(params[:amount])
      end
      raise StoredValue::Error, "amount must be positive" if amount_cents.nil? || !amount_cents.positive?

      to_account = StoredValue::EnsureCustomerAccount.call(customer: to_customer, account_type: account_type)
      approved_by = StoredValue::AuthenticateApprover.call(
        username: params[:approver_username],
        password: params[:approver_password],
        performer: current_user,
        permission_key: "stored_value.transfer",
        store: operational_store!
      )
      StoredValue::Transfer.call(
        from_account: from_account,
        to_account: to_account,
        amount_cents: amount_cents,
        transfer_type: transfer_type,
        performed_by: current_user,
        approved_by: approved_by,
        store: operational_store!,
        source_id: from_account.id,
        idempotency_key: params[:idempotency_key].presence || SecureRandom.uuid_v7,
        reason_code: params[:reason_code].presence || transfer_type,
        reason_name_snapshot: params[:reason_name].presence || transfer_type.humanize,
        notes: params[:notes]
      )
      redirect_to admin_customer_path(to_customer), notice: "Stored-value transfer posted."
    rescue StoredValue::Error, ActiveRecord::RecordNotFound, Money::ParseCents::Error, ArgumentError => e
      @from_customer = Customer.find_by(id: params[:from_customer_id])
      @account_type = params[:account_type]
      flash.now[:alert] = e.message
      render :new, status: :unprocessable_entity
    end

    private

    def operational_store!
      current_store || Store.active.order(:name).first || raise(StoredValue::Error, "a store is required")
    end

    def open_customer_account(customer, account_type)
      StoredValueAccount.where(customer_id: customer.id, account_type: account_type)
                        .where.not(status: "closed").order(:id).first
    end
  end
end
