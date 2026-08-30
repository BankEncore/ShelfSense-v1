# frozen_string_literal: true

module Pos
  class CustomerSummariesController < BaseController
    def show
      prepare_inquiry_shell!(surface: :customer_summary)
      @can_open_customer = Authorization::PermissionEvaluator.allowed?(
        user: current_user,
        permission_key: "customers.view",
        store: current_store
      )

      if params[:customer_id].present?
        @customer = Customer.active.canonical.find_by(id: params[:customer_id])
        unless @customer
          flash.now[:alert] = "Customer not found."
          return
        end

        load_customer_summary!(@customer)
        return
      end

      query = params[:q].to_s.strip
      return if query.blank?

      @matches = Customers::Search.call(query: query, mode: :operational, limit: 20)
      flash.now[:alert] = "No matching customers." if @matches.empty?
    end

    private

    def load_customer_summary!(customer)
      @store_credit_account = customer.stored_value_accounts.find_by(account_type: "store_credit")
      @open_requests = customer.customer_requests
                               .for_store(current_store)
                               .where(status: CustomerRequest::ACTIVE_STATUSES)
                               .includes(:product_variant, :customer_request_allocations)
                               .admin_ordered
                               .limit(20)
      @ready_pickups = @open_requests.select(&:available?)
      @recent_transactions = PosTransaction.completed
                                           .where(store_id: current_store.id, customer_id: customer.id)
                                           .order(completed_at: :desc)
                                           .limit(10)
    end
  end
end
