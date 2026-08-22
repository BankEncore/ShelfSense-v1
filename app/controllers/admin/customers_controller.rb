# frozen_string_literal: true

module Admin
  class CustomersController < BaseController
    before_action -> { require_permission!("customers.view") }, only: %i[index show]
    before_action -> { require_permission!("customers.manage") }, only: %i[new create edit update destroy reactivate]
    before_action :set_customer, only: %i[show edit update destroy reactivate]

    def index
      @customers = Customer.admin_ordered
    end

    def show
      @customer_requests = @customer.customer_requests.includes(:store, :product_variant).admin_ordered.limit(50)
    end

    def new
      @customer = Customer.new
    end

    def create
      @customer = Customer.new(customer_params.except(:lock_version))
      if create_and_audit!(
        @customer,
        action: "customers.create",
        after_values: { display_name: @customer.display_name, email: @customer.email, phone: @customer.phone }
      )
        redirect_to admin_customer_path(@customer), notice: "Customer created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      rescue_stale do
        if save_and_audit!(
          @customer,
          attrs: customer_params,
          action: "customers.update",
          before_keys: audit_attribute_keys
        )
          redirect_to admin_customer_path(@customer), notice: "Customer updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end
    end

    def destroy
      mutate_and_audit!(@customer, action: "customers.deactivate") { @customer.update!(active: false) }
      redirect_to admin_customers_path, notice: "Customer deactivated."
    end

    def reactivate
      reactivate_configuration!(
        @customer,
        permission_key: "customers.manage",
        audit_action: "customers.reactivate",
        redirect_path: admin_customer_path(@customer)
      )
    end

    private

    def set_customer
      @customer = Customer.find(params[:id])
    end

    def audit_attribute_keys
      %w[display_name email phone notes active]
    end

    def customer_params
      params.require(:customer).permit(:display_name, :email, :phone, :notes, :lock_version)
    end
  end
end
