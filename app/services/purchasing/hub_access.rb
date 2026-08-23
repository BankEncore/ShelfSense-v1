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

    def permission_allowed_anywhere?(user:, permission_keys:, accessible_stores:)
      permission_keys.any? do |key|
        Authorization::PermissionEvaluator.allowed?(user: user, permission_key: key, store: nil) ||
          accessible_stores.any? do |store|
            Authorization::PermissionEvaluator.allowed?(user: user, permission_key: key, store: store)
          end
      end
    end
  end
end
