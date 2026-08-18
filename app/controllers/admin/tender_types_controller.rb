# frozen_string_literal: true

module Admin
  class TenderTypesController < BaseController
    before_action -> { require_permission!("pos.manage_tender_types") }
    before_action :set_tender_type, only: %i[show edit update destroy reactivate]

    def index
      @tender_types = TenderType.admin_ordered
    end

    def show; end

    def new
      @tender_type = TenderType.new(
        behavioral_category: "other",
        external_reference_policy: "optional",
        active: true
      )
    end

    def create
      @tender_type = TenderType.new(create_params)
      @tender_type.behavioral_category = "other"
      @tender_type.system_protected = false
      if create_and_audit!(
        @tender_type,
        action: "tender_types.create",
        after_values: { code: @tender_type.code, name: @tender_type.name, behavioral_category: "other" }
      )
        redirect_to admin_tender_type_path(@tender_type), notice: "Tender type created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      rescue_stale do
        attrs = update_params
        attrs = attrs.except(:active) if @tender_type.cash?
        if save_and_audit!(
          @tender_type,
          attrs: attrs,
          action: "tender_types.update",
          before_keys: %w[name active external_reference_policy]
        )
          redirect_to admin_tender_type_path(@tender_type), notice: "Tender type updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end
    end

    def destroy
      if @tender_type.system_protected?
        redirect_to admin_tender_type_path(@tender_type), alert: "System identities cannot be deleted."
        return
      end

      mutate_and_audit!(@tender_type, action: "tender_types.deactivate") do
        @tender_type.update!(active: false)
      end
      redirect_to admin_tender_types_path, notice: "Tender type deactivated."
    end

    def reactivate
      if @tender_type.system_protected? && @tender_type.cash?
        redirect_to admin_tender_type_path(@tender_type), alert: "Cash cannot be deactivated."
        return
      end

      reactivate_configuration!(
        @tender_type,
        permission_key: "pos.manage_tender_types",
        audit_action: "tender_types.reactivate",
        redirect_path: admin_tender_type_path(@tender_type)
      )
    end

    private

    def set_tender_type
      @tender_type = TenderType.find(params[:id])
    end

    def create_params
      params.require(:tender_type).permit(:code, :name, :external_reference_policy, :lock_version)
    end

    def update_params
      params.require(:tender_type).permit(:name, :active, :external_reference_policy, :lock_version)
    end
  end
end
