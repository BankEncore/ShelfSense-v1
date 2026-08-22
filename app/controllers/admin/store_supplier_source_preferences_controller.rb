# frozen_string_literal: true

module Admin
  class StoreSupplierSourcePreferencesController < BaseController
    before_action -> { require_permission!("suppliers.manage") }
    before_action :set_supplier_variant_source, only: :create
    before_action :set_preference, only: :destroy

    def create
      store = Store.find(preference_params[:store_id])
      return unless authorize_store!(store)

      preference = StoreSupplierSourcePreference.find_or_initialize_by(
        store_id: store.id,
        product_variant_id: @supplier_variant_source.product_variant_id
      )
      preference.supplier_variant_source = @supplier_variant_source
      if preference.persisted? && preference_params[:lock_version].present?
        preference.lock_version = preference_params[:lock_version]
      end

      if create_or_update_preference!(preference)
        redirect_to after_preference_path(@supplier_variant_source),
                    notice: "Store preferred source updated."
      else
        redirect_to after_preference_path(@supplier_variant_source),
                    alert: preference.errors.full_messages.to_sentence.presence || "Could not save store preference."
      end
    end

    def destroy
      return unless authorize_store!(@preference.store)

      source = @preference.supplier_variant_source
      mutate_and_audit!(
        @preference,
        action: "store_supplier_source_preferences.destroy",
        before_values: {
          store_id: @preference.store_id,
          product_variant_id: @preference.product_variant_id,
          supplier_variant_source_id: @preference.supplier_variant_source_id
        }
      ) { @preference.destroy! }

      redirect_to after_preference_path(source),
                  notice: "Store preferred source cleared."
    end

    private

    def set_supplier_variant_source
      @supplier_variant_source = SupplierVariantSource.find(params[:supplier_variant_source_id])
    end

    def set_preference
      @preference = StoreSupplierSourcePreference.find(params[:id])
    end

    def preference_params
      params.require(:store_supplier_source_preference).permit(:store_id, :lock_version)
    end

    def after_preference_path(source)
      if params[:return_to] == "variant"
        admin_product_variant_path(source.product_variant)
      else
        admin_supplier_variant_source_path(source)
      end
    end

    def authorize_store!(store)
      return true if Authorization::PermissionEvaluator.allowed?(
        user: current_user,
        permission_key: "suppliers.manage",
        store: store
      )

      Audit::Recorder.record!(
        action: "authorization.denied",
        outcome: "denied",
        actor_user: current_user,
        actor_label: current_user.display_name,
        store: store,
        reason_code: "suppliers.manage",
        metadata: { path: request.fullpath, store_id: store.id }
      )
      redirect_to root_path, alert: "You are not authorized to perform that action."
      false
    end

    def create_or_update_preference!(preference)
      preference.class.transaction do
        was_new = preference.new_record?
        before = was_new ? nil : preference.attributes.slice(
          "store_id", "product_variant_id", "supplier_variant_source_id"
        )
        return false unless preference.save

        Audit::Recorder.record!(
          action: was_new ? "store_supplier_source_preferences.create" : "store_supplier_source_preferences.update",
          outcome: "succeeded",
          actor_user: current_user,
          actor_label: current_user.display_name,
          store: preference.store,
          subject: preference,
          before_values: before,
          after_values: preference.attributes.slice(
            "store_id", "product_variant_id", "supplier_variant_source_id"
          )
        )
      end
      true
    rescue ActiveRecord::StaleObjectError
      preference.errors.add(:base, "This record was changed by someone else. Reload and try again.")
      false
    end
  end
end
