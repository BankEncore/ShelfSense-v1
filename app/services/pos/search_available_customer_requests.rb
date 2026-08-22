# frozen_string_literal: true

module Pos
  class SearchAvailableCustomerRequests
    LIMIT = 20

    Row = Struct.new(
      :customer_request,
      :allocation,
      :request_number,
      :customer_name,
      :customer_phone,
      :merchandise_label,
      :allocation_type,
      :unit_identifier,
      keyword_init: true
    )

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(store:, query:)
      @store = store
      @query = query.to_s.strip
    end

    def call
      return [] if @query.blank?

      scope = CustomerRequest
        .available
        .for_store(@store)
        .joins(:customer, :product_variant, :customer_request_allocations)
        .joins("INNER JOIN products ON products.id = product_variants.product_id")
        .merge(CustomerRequestAllocation.reserved)
        .includes(
          :customer,
          product_variant: [ :product, :merchandise_condition ],
          customer_request_allocations: :inventory_unit
        )

      binds = []
      conditions = []

      if @query.match?(/\A\d{1,9}\z/)
        conditions << "customer_requests.number = ?"
        binds << @query.to_i
      end

      like = "%#{sanitize_like(@query)}%"
      conditions << "customers.display_name ILIKE ?"
      binds << like
      conditions << "customers.phone ILIKE ?"
      binds << like
      conditions << "products.name ILIKE ?"
      binds << like
      conditions << "product_variants.sku ILIKE ?"
      binds << "#{sanitize_like(@query)}%"

      unit_norm = begin
        Identifiers::Normalizer.normalize(@query, allow_shelfsense_222: false)
      rescue Identifiers::NormalizationError
        nil
      end
      if unit_norm.present?
        conditions << "EXISTS (
          SELECT 1 FROM inventory_units iu
          WHERE iu.id = customer_request_allocations.inventory_unit_id
            AND iu.unit_identifier = ?
        )"
        binds << unit_norm
      end

      scope.where(conditions.join(" OR "), *binds)
           .order("customer_requests.number DESC")
           .limit(LIMIT)
           .map { |request| build_row(request) }
    end

    private

    def build_row(request)
      allocation = request.active_allocation
      variant = request.product_variant
      Row.new(
        customer_request: request,
        allocation: allocation,
        request_number: request.number,
        customer_name: request.customer.display_name,
        customer_phone: request.customer.phone,
        merchandise_label: [ variant.product.name, variant.sku ].compact.join(" · "),
        allocation_type: allocation&.allocation_type,
        unit_identifier: allocation&.inventory_unit&.unit_identifier
      )
    end

    def sanitize_like(value)
      value.gsub(/[%_\\]/) { |match| "\\#{match}" }
    end
  end
end
