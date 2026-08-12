# frozen_string_literal: true

module Admin
  class InventoryBalancesController < BaseController
    before_action -> { require_permission!("inventory.view") }, only: %i[index show history]
    before_action -> { require_permission!("inventory.reconcile") }, only: %i[rebuild confirm_rebuild]
    before_action :set_balance, only: %i[show history rebuild confirm_rebuild]

    def index
      store_ids =
        if Authorization::PermissionEvaluator.allowed?(user: current_user, permission_key: "inventory.view", store: nil)
          current_store ? [ current_store.id ] : Store.active.pluck(:id)
        else
          accessible_stores.pluck(:id)
        end
      store_ids = [ current_store.id ] if current_store && store_ids.include?(current_store.id)

      @index = Inventory::AdminIndexQuery.call(
        store_ids: store_ids,
        q: params[:q],
        tracking: params[:tracking],
        page: params[:page]
      )
      @balances = @index.records
    end

    def show
      @unit_count =
        if @balance.product_variant.derived_inventory_tracking == "individual"
          InventoryUnit.on_hand.where(store_id: @balance.store_id, product_variant_id: @balance.product_variant_id).count
        end
    end

    def history
      @ledger_entries = InventoryLedgerEntry.where(store_id: @balance.store_id, product_variant_id: @balance.product_variant_id)
        .order(occurred_at: :desc, created_at: :desc)
      @valuation_entries = InventoryValuationEntry.where(store_id: @balance.store_id, product_variant_id: @balance.product_variant_id)
        .index_by { |e| [ e.source_type, e.source_id, e.effect_sequence ] }
    end

    def rebuild
      return unless authorize!("inventory.reconcile", store: @balance.store)

      @command_token = SecureRandom.uuid_v7
      @idempotency_key = SecureRandom.uuid_v7
    end

    def confirm_rebuild
      return unless authorize!("inventory.reconcile", store: @balance.store)

      Inventory::RebuildProjection.call(
        store: @balance.store,
        product_variant: @balance.product_variant,
        actor: current_user,
        source_id: params.require(:command_token),
        idempotency_key: params.require(:idempotency_key)
      )
      redirect_to admin_inventory_balance_path(@balance), notice: "Projection rebuilt."
    rescue Inventory::RebuildProjection::Error => e
      redirect_to rebuild_admin_inventory_balance_path(@balance), alert: e.message
    end

    private

    def set_balance
      @balance = InventoryBalance.find(params[:id])
      throw :abort unless authorize!("inventory.view", store: @balance.store)
    end
  end
end
