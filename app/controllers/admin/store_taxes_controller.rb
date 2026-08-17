# frozen_string_literal: true

module Admin
  class StoreTaxesController < BaseController
    before_action -> { require_permission!("store_taxes.view") }, only: %i[index show]
    before_action -> { require_permission!("store_taxes.create") }, only: %i[new create]
    before_action -> { require_permission!("store_taxes.update") }, only: %i[edit update]
    before_action -> { require_permission!("store_taxes.deactivate") }, only: %i[destroy reactivate]
    before_action :require_store_context
    before_action :set_store_tax, only: %i[show edit update destroy reactivate]

    def index
      @store_taxes = StoreTax.where(store: current_store).calculation_ordered
    end

    def show
      load_rules
    end

    def new
      @store_tax = StoreTax.new(store: current_store, calculation_order: 0)
      @tax_classes = TaxClass.assignable.admin_ordered
    end

    def create
      @store_tax = StoreTaxes::Create.call(
        store: current_store,
        actor: current_user,
        **store_tax_service_attrs
      )
      redirect_to admin_store_tax_path(@store_tax), notice: "Store tax created."
    rescue StoreTaxes::Create::Error => e
      @store_tax = StoreTax.new(store: current_store, **store_tax_params.to_h.symbolize_keys.except(:lock_version, :applies_by_tax_class_id))
      @store_tax.errors.add(:base, e.message)
      @tax_classes = TaxClass.assignable.admin_ordered
      render :new, status: :unprocessable_entity
    end

    def edit
      load_rules
    end

    def update
      StoreTaxes::Update.call(
        store_tax: @store_tax,
        actor: current_user,
        expected_lock_version: store_tax_params[:lock_version],
        **store_tax_service_attrs
      )
      redirect_to admin_store_tax_path(@store_tax), notice: "Store tax updated."
    rescue StoreTaxes::Update::Error => e
      @store_tax.errors.add(:base, e.message)
      load_rules
      render :edit, status: :unprocessable_entity
    end

    def destroy
      mutate_and_audit!(@store_tax, action: "store_taxes.deactivate") { @store_tax.update!(active: false) }
      redirect_to admin_store_taxes_path, notice: "Store tax deactivated."
    end

    def reactivate
      rescue_stale do
        StoreTaxes::Reactivate.call(
          store_tax: @store_tax,
          actor: current_user,
          expected_lock_version: params.dig(:store_tax, :lock_version) || params[:lock_version]
        )
        redirect_to admin_store_tax_path(@store_tax), notice: "Store tax reactivated."
      rescue StoreTaxes::Reactivate::Error => e
        redirect_to admin_store_tax_path(@store_tax), alert: e.message
      end
    end

    private

    def set_store_tax
      @store_tax = StoreTax.where(store: current_store).find(params[:id])
    end

    def load_rules
      StoreTaxes::EnsureRules.for_store_tax(@store_tax)
      @tax_classes = TaxClass.assignable.admin_ordered
      @rules_by_tax_class_id = @store_tax.store_tax_rules.index_by(&:tax_class_id)
    end

    def store_tax_params
      params.require(:store_tax).permit(:code, :name, :rate_percent, :calculation_order, :lock_version, applies_by_tax_class_id: {})
    end

    def store_tax_service_attrs
      {
        code: store_tax_params[:code],
        name: store_tax_params[:name],
        rate_percent: store_tax_params[:rate_percent],
        calculation_order: store_tax_params[:calculation_order],
        applies_by_tax_class_id: store_tax_params[:applies_by_tax_class_id] || {}
      }
    end
  end
end
