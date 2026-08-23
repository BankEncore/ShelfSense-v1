# frozen_string_literal: true

module Purchasing
  module HubAccess
    HUB_PERMISSIONS = %w[
      customer_requests.locate
      orders.view
      orders.manage
      purchase_receipts.view
      purchase_receipts.manage
    ].freeze

    module_function

    def nav_visible?(user:, accessible_stores:)
      return false unless user&.active?

      permission_allowed_anywhere?(user:, permission_keys: HUB_PERMISSIONS, accessible_stores:)
    end

    def hub_allowed?(user:, accessible_stores:)
      nav_visible?(user:, accessible_stores:)
    end

    # Evaluates at most one permission set for the global scope, then one set per
    # accessible store, stopping at the first matching hub-eligible key.
    def permission_allowed_anywhere?(user:, permission_keys:, accessible_stores:)
      wanted = permission_keys.to_set
      return false if wanted.empty?

      global_keys = Authorization::PermissionEvaluator.permissions_for(user: user, store: nil)
      return true if wanted.intersect?(global_keys)

      accessible_stores.any? do |store|
        store_keys = Authorization::PermissionEvaluator.permissions_for(user: user, store: store)
        wanted.intersect?(store_keys)
      end
    end
  end
end
