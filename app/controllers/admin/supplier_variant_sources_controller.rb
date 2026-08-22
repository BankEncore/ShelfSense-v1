# frozen_string_literal: true

module Admin
  class SupplierVariantSourcesController < BaseController
    rescue_from Money::ParseCents::Error, with: :render_money_error
    before_action -> { require_permission!("suppliers.view") }, only: %i[show]
    before_action -> { require_permission!("suppliers.manage") }, only: %i[new create edit update destroy reactivate]
    before_action :set_supplier, only: %i[new create], if: -> { params[:supplier_id].present? }
    before_action :set_product_variant, only: %i[new create], if: -> { params[:product_variant_id].present? }
    before_action :set_supplier_variant_source, only: %i[show edit update destroy reactivate]
    helper_method :supplier_variant_source_form_model

    def show
      @supplier = @supplier_variant_source.supplier
      @product_variant = @supplier_variant_source.product_variant
      @store_preferences = @supplier_variant_source.store_supplier_source_preferences.includes(:store)
      @stores = Store.active.admin_ordered
    end

    def new
      if @product_variant
        assert_variant_sourceable!(@product_variant)
        @supplier_variant_source = @product_variant.supplier_variant_sources.build(
          pricing_method: "direct_unit_cost",
          organization_preferred: false,
          active: true
        )
        @suppliers = Supplier.active.admin_ordered
        @return_to = "variant"
      else
        @supplier_variant_source = @supplier.supplier_variant_sources.build(
          pricing_method: "direct_unit_cost",
          organization_preferred: false,
          active: true
        )
        load_variant_options
      end
    end

    def create
      if @product_variant
        assert_variant_sourceable!(@product_variant)
        attrs = source_params.except(:lock_version)
        supplier_id = attrs.delete(:supplier_id)
        raise ActiveRecord::RecordNotFound, "Supplier is required" if supplier_id.blank?

        @supplier = Supplier.active.find(supplier_id)
        @supplier_variant_source = @supplier.supplier_variant_sources.build(
          attrs.except(:product_variant_id).merge(product_variant: @product_variant)
        )
        @return_to = "variant"
      else
        @supplier_variant_source = @supplier.supplier_variant_sources.build(
          source_params.except(:lock_version, :supplier_id)
        )
      end

      if create_and_audit!(
        @supplier_variant_source,
        action: "supplier_variant_sources.create",
        after_values: source_audit_values(@supplier_variant_source)
      )
        redirect_to after_mutation_path(@supplier_variant_source),
                    notice: "Supplier source created."
      else
        prepare_form_rerender
        render :new, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotFound => e
      flash.now[:alert] = e.message
      @supplier_variant_source ||= begin
        attrs = params.fetch(:supplier_variant_source, {}).permit(
          :supplier_id, :product_variant_id, :supplier_item_number, :pricing_method,
          :supplier_list_price_cents, :discount_basis_points, :expected_unit_cost_cents,
          :organization_preferred
        )
        SupplierVariantSource.new(attrs)
      end
      prepare_form_rerender
      render :new, status: :unprocessable_entity
    end

    def edit
      @supplier = @supplier_variant_source.supplier
      @product_variant = @supplier_variant_source.product_variant
      @return_to = params[:return_to]
    end

    def update
      @supplier = @supplier_variant_source.supplier
      @product_variant = @supplier_variant_source.product_variant
      @return_to = params[:return_to].presence
      rescue_stale do
        if save_and_audit!(
          @supplier_variant_source,
          attrs: source_params.except(:product_variant_id, :supplier_id),
          action: "supplier_variant_sources.update",
          before_keys: source_audit_keys
        )
          redirect_to after_mutation_path(@supplier_variant_source),
                      notice: "Supplier source updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end
    end

    def destroy
      @return_to = params[:return_to]
      mutate_and_audit!(
        @supplier_variant_source,
        action: "supplier_variant_sources.deactivate"
      ) { @supplier_variant_source.update!(active: false) }
      redirect_to after_destroy_path(@supplier_variant_source),
                  notice: "Supplier source deactivated."
    end

    def reactivate
      @return_to = params[:return_to]
      reactivate_configuration!(
        @supplier_variant_source,
        permission_key: "suppliers.manage",
        audit_action: "supplier_variant_sources.reactivate",
        redirect_path: after_mutation_path(@supplier_variant_source)
      )
    end

    private

    def render_money_error(exception)
      @supplier_variant_source ||= SupplierVariantSource.new
      @supplier_variant_source.errors.add(:base, exception.message)
      prepare_form_rerender
      render(action_name == "update" ? :edit : :new, status: :unprocessable_entity)
    end

    def set_supplier
      @supplier = Supplier.find(params[:supplier_id])
    end

    def set_product_variant
      @product_variant = ProductVariant.find(params[:product_variant_id])
    end

    def set_supplier_variant_source
      @supplier_variant_source = SupplierVariantSource.find(params[:id])
    end

    def load_variant_options
      @standard_variants = ProductVariant.standard
        .where(inventory_mode: "inventory")
        .order(:sku)
        .includes(:product)
    end

    def assert_variant_sourceable!(variant)
      return if variant.standard? && variant.inventory_mode == "inventory"

      raise ActiveRecord::RecordNotFound, "Only Standard inventory variants accept supplier sources"
    end

    def prepare_form_rerender
      if @product_variant
        @suppliers = Supplier.active.admin_ordered
        @return_to = "variant"
      else
        load_variant_options
      end
    end

    def after_mutation_path(source)
      if @return_to == "variant"
        admin_product_variant_path(source.product_variant)
      else
        admin_supplier_variant_source_path(source)
      end
    end

    def after_destroy_path(source)
      if @return_to == "variant"
        admin_product_variant_path(source.product_variant)
      else
        admin_supplier_path(source.supplier)
      end
    end

    def supplier_variant_source_form_model(source)
      if source.persisted?
        [ :admin, source ]
      elsif @product_variant
        [ :admin, @product_variant, source ]
      else
        [ :admin, @supplier, source ]
      end
    end

    def source_audit_keys
      %w[
        product_variant_id supplier_id supplier_item_number pricing_method
        supplier_list_price_cents discount_basis_points expected_unit_cost_cents
        organization_preferred active
      ]
    end

    def source_audit_values(source)
      source.attributes.slice(*source_audit_keys)
    end

    def source_params
      permitted = params.require(:supplier_variant_source).permit(
        :supplier_id, :product_variant_id, :supplier_item_number, :pricing_method,
        :supplier_list_price_cents, :discount_basis_points, :expected_unit_cost_cents,
        :organization_preferred, :lock_version
      )
      %i[supplier_list_price_cents discount_basis_points expected_unit_cost_cents].each do |key|
        permitted[key] = nil if permitted[key].blank?
      end
      %i[supplier_list_price_cents expected_unit_cost_cents].each do |key|
        permitted[key] = Money::ParseCents.call(permitted[key]) if permitted[key].present?
      end
      permitted[:organization_preferred] = ActiveModel::Type::Boolean.new.cast(permitted[:organization_preferred])
      permitted
    end
  end
end
