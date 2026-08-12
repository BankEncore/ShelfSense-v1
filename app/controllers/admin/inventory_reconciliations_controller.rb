# frozen_string_literal: true

module Admin
  class InventoryReconciliationsController < BaseController
    before_action -> { require_permission!("inventory.reconcile") }

    def show
      @drifts = Inventory::Reconcile.call(store: current_store)
    end
  end
end
