# frozen_string_literal: true

module Pos
  class PickupQueuesController < BaseController
    def index
      prepare_inquiry_shell!(surface: :pickup_queue)
      @query = params[:q].to_s.strip
      @status = params[:status].presence_in(%w[available all]) || "available"

      scope = CustomerRequest.for_store(current_store)
                             .includes(
                               :customer,
                               product_variant: [ :product, :merchandise_condition ],
                               customer_request_allocations: :inventory_unit
                             )

      scope = if @status == "available"
        scope.available
      else
        scope.where(status: CustomerRequest::ACTIVE_STATUSES)
      end

      if @query.present?
        rows = Pos::SearchAvailableCustomerRequests.call(store: current_store, query: @query)
        ids = rows.map { |row| row.customer_request.id }
        scope = scope.where(id: ids)
      end

      @requests = scope.admin_ordered.limit(50)
      @selected = @requests.find { |request| request.id.to_s == params[:request_id].to_s } if params[:request_id].present?
      @selected ||= @requests.first
      @can_view_request = Authorization::PermissionEvaluator.allowed?(
        user: current_user,
        permission_key: "customers.view",
        store: current_store
      )
    end
  end
end
