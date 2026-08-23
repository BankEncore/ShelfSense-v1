# frozen_string_literal: true

module Purchasing
  class WorkHubSummary
    Section = Data.define(
      :key,
      :title,
      :count,
      :clear_text,
      :primary_label,
      :primary_path,
      :history_label,
      :history_path,
      :dominant_primary
    )

    def initialize(user:, store:, accessible_stores:)
      @user = user
      @store = store
      @accessible_stores = accessible_stores
    end

    def store_selected?
      @store.present?
    end

    def operational_sections
      return [] unless store_selected?

      [
        location_section,
        draft_po_section,
        sent_po_section,
        receipt_drafts_section
      ].compact
    end

    def history_sections
      [
        orders_history_section,
        purchase_orders_history_section,
        receipts_history_section
      ].compact
    end

    private

    def allowed?(permission_key, store: @store)
      Authorization::PermissionEvaluator.allowed?(
        user: @user,
        permission_key: permission_key,
        store: store
      )
    end

    def location_section
      return unless allowed?("customer_requests.locate")

      count = CustomerRequest.pending_location.for_store(@store).count
      Section.new(
        key: :location_queue,
        title: "Requests awaiting location",
        count: count,
        clear_text: "None awaiting",
        primary_label: count.positive? ? "Open location queue" : nil,
        primary_path: count.positive? ? Rails.application.routes.url_helpers.ops_location_path : nil,
        history_label: "View customer requests",
        history_path: Rails.application.routes.url_helpers.admin_customer_requests_path,
        dominant_primary: count.positive?
      )
    end

    def draft_po_section
      return unless allowed?("orders.manage")

      count = PurchaseOrder.draft.for_store(@store).count
      Section.new(
        key: :draft_pos,
        title: "Draft purchase orders",
        count: count,
        clear_text: "None open",
        primary_label: count.positive? ? "Continue draft POs" : nil,
        primary_path: count.positive? ? Rails.application.routes.url_helpers.ops_draft_pos_path : nil,
        history_label: "View purchase order history",
        history_path: Rails.application.routes.url_helpers.admin_purchase_orders_path(status: "draft"),
        dominant_primary: count.positive?
      )
    end

    def sent_po_section
      return unless allowed?("orders.view")

      count = PurchaseOrder.sent.for_store(@store).with_open_lines.count
      Section.new(
        key: :sent_pos,
        title: "Sent purchase orders awaiting receipt",
        count: count,
        clear_text: "None awaiting receipt",
        primary_label: count.positive? ? "View sent POs" : nil,
        primary_path: count.positive? ? Rails.application.routes.url_helpers.admin_purchase_orders_path(status: "sent") : nil,
        history_label: "View purchase order history",
        history_path: Rails.application.routes.url_helpers.admin_purchase_orders_path,
        dominant_primary: count.positive?
      )
    end

    def receipt_drafts_section
      return unless allowed?("purchase_receipts.manage")

      count = PurchaseReceipt.draft.for_store(@store).count
      Section.new(
        key: :receipt_drafts,
        title: "Receipt drafts in progress",
        count: count,
        clear_text: "None in progress",
        primary_label: count.positive? ? "Continue receiving" : nil,
        primary_path: count.positive? ? Rails.application.routes.url_helpers.ops_receiving_index_path : nil,
        history_label: "Open receiving workspace",
        history_path: Rails.application.routes.url_helpers.ops_receiving_index_path,
        dominant_primary: count.positive?
      )
    end

    def orders_history_section
      return unless allowed?("orders.view", store: nil) || allowed?("orders.view")

      Section.new(
        key: :orders_history,
        title: "Order history",
        count: nil,
        clear_text: nil,
        primary_label: nil,
        primary_path: nil,
        history_label: "View all orders",
        history_path: Rails.application.routes.url_helpers.admin_orders_path,
        dominant_primary: false
      )
    end

    def purchase_orders_history_section
      return unless allowed?("orders.view", store: nil) || allowed?("orders.view")

      Section.new(
        key: :purchase_orders_history,
        title: "Purchase order history",
        count: nil,
        clear_text: nil,
        primary_label: nil,
        primary_path: nil,
        history_label: "View all purchase orders",
        history_path: Rails.application.routes.url_helpers.admin_purchase_orders_path,
        dominant_primary: false
      )
    end

    def receipts_history_section
      return unless allowed?("purchase_receipts.view", store: nil) || allowed?("purchase_receipts.view")

      Section.new(
        key: :receipts_history,
        title: "Purchase receipt history",
        count: nil,
        clear_text: nil,
        primary_label: nil,
        primary_path: nil,
        history_label: "View posted receipts",
        history_path: Rails.application.routes.url_helpers.admin_purchase_receipts_path,
        dominant_primary: false
      )
    end
  end
end
