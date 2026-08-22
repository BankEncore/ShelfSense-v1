# frozen_string_literal: true

module Admin
  class SuppliersController < BaseController
    before_action -> { require_permission!("suppliers.view") }, only: %i[index show]
    before_action -> { require_permission!("suppliers.manage") }, only: %i[new create edit update destroy reactivate]
    before_action :set_supplier, only: %i[show edit update destroy reactivate]

    def index
      @suppliers = Supplier.admin_ordered
    end

    def show
      @supplier_variant_sources = @supplier.supplier_variant_sources
        .includes(:product_variant)
        .admin_ordered
    end

    def new
      @supplier = Supplier.new
    end

    def create
      @supplier = Supplier.new(supplier_params.except(:lock_version))
      if create_and_audit!(
        @supplier,
        action: "suppliers.create",
        after_values: { code: @supplier.code, name: @supplier.name }
      )
        redirect_to admin_supplier_path(@supplier), notice: "Supplier created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      rescue_stale do
        if save_and_audit!(
          @supplier,
          attrs: supplier_params.except(:code),
          action: "suppliers.update",
          before_keys: audit_attribute_keys - %w[code]
        )
          redirect_to admin_supplier_path(@supplier), notice: "Supplier updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end
    end

    def destroy
      mutate_and_audit!(
        @supplier,
        action: "suppliers.deactivate",
        before_values: { active: true },
        after_values: { active: false }
      ) { @supplier.update!(active: false) }
      redirect_to admin_suppliers_path, notice: "Supplier deactivated."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_supplier_path(@supplier),
                  alert: e.record.errors.full_messages.to_sentence.presence || e.message
    end

    def reactivate
      reactivate_configuration!(
        @supplier,
        permission_key: "suppliers.manage",
        audit_action: "suppliers.reactivate",
        redirect_path: admin_supplier_path(@supplier)
      )
    end

    private

    def set_supplier
      @supplier = Supplier.find(params[:id])
    end

    def audit_attribute_keys
      %w[
        code name account_number contact_name email phone
        street_address_1 street_address_2 city region_code postal_code country_code
        ordering_notes active
      ]
    end

    def supplier_params
      params.require(:supplier).permit(
        :code, :name, :account_number, :contact_name, :email, :phone,
        :street_address_1, :street_address_2, :city, :region_code, :postal_code,
        :country_code, :ordering_notes, :lock_version
      )
    end
  end
end
