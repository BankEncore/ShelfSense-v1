# frozen_string_literal: true

module Admin
  class StoresController < BaseController
    before_action -> { require_permission!("stores.view") }, only: %i[index show]
    before_action -> { require_permission!("stores.create") }, only: %i[new create]
    before_action -> { require_permission!("stores.manage") }, only: %i[edit update]
    before_action -> { require_permission!("stores.deactivate") }, only: :destroy
    before_action :set_store, only: %i[show edit update destroy]

    def index
      @stores = if Authorization::PermissionEvaluator.allowed?(user: current_user, permission_key: "stores.view", store: nil)
        Store.admin_ordered
      else
        accessible_stores
      end
    end

    def show; end

    def new
      @store = Store.new
    end

    def create
      @store = Store.new(store_params.except(:lock_version))
      if @store.save
        Audit::Recorder.record!(
          action: "stores.create",
          outcome: "succeeded",
          actor_user: current_user,
          actor_label: current_user.display_name,
          store: @store,
          subject: @store,
          after_values: { code: @store.code, name: @store.name }
        )
        redirect_to admin_store_path(@store), notice: "Store created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      rescue_stale do
        before = @store.attributes.slice(
          "name", "legal_name", "phone", "street_address_1", "street_address_2",
          "city", "region_code", "postal_code", "country_code", "timezone",
          "receipt_header_mode", "receipt_header", "receipt_footer_mode", "receipt_footer",
          "cash_variance_note_threshold_cents",
          "cash_variance_approval_threshold_cents",
          "cash_paid_out_approval_threshold_cents"
        )
        if @store.update(store_params)
          Audit::Recorder.record!(
            action: "stores.update",
            outcome: "succeeded",
            actor_user: current_user,
            actor_label: current_user.display_name,
            store: @store,
            subject: @store,
            before_values: before,
            after_values: @store.attributes.slice(*before.keys)
          )
          redirect_to admin_store_path(@store), notice: "Store updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end
    end

    def destroy
      if Store.active.where.not(id: @store.id).none?
        redirect_to admin_store_path(@store), alert: "Cannot deactivate the final active store."
        return
      end

      unless @store.update(active: false, deactivated_at: Time.current, deactivated_by: current_user)
        redirect_to admin_store_path(@store), alert: @store.errors.full_messages.to_sentence
        return
      end

      Audit::Recorder.record!(
        action: "stores.deactivate",
        outcome: "succeeded",
        actor_user: current_user,
        actor_label: current_user.display_name,
        store: @store,
        subject: @store
      )
      redirect_to admin_stores_path, notice: "Store deactivated."
    end

    private

    def set_store
      @store = Store.find(params[:id])
    end

    def store_params
      permitted = [
        :code, :name, :legal_name, :street_address_1, :street_address_2,
        :city, :region_code, :postal_code, :country_code, :phone, :san, :timezone,
        :receipt_header, :receipt_footer, :receipt_header_mode, :receipt_footer_mode, :lock_version,
        :cash_variance_note_threshold_cents, :cash_variance_approval_threshold_cents,
        :cash_paid_out_approval_threshold_cents
      ]
      permitted.unshift(:store_number) unless @store&.store_number_locked?
      attrs = params.require(:store).permit(*permitted)
      %i[
        cash_variance_note_threshold_cents
        cash_variance_approval_threshold_cents
        cash_paid_out_approval_threshold_cents
      ].each { |key| attrs[key] = attrs[key].presence }
      attrs
    end
  end
end
