# frozen_string_literal: true

module Customers
  # Shared customer lookup for admin index, request customer pick, and alias resolution.
  #
  # Modes:
  # - :operational (default) — active canonical customers for new work
  # - :canonical — active and inactive canonical customers (default management index)
  # - :admin_index — all customers including merged tombstones (historical browse)
  class Search
    Result = Data.define(:customer, :matched_former_customer)

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(query:, scope: nil, mode: :operational, limit: 100)
      @query = query.to_s.strip
      @scope = scope || Customer.all
      @mode = mode
      @limit = limit
    end

    def call
      relation = base_scope
      if @query.present?
        matched_ids = matching_customer_ids
        return [] if matched_ids.empty?

        relation = relation.where(id: matched_ids)
      end

      customers = relation.admin_ordered.limit(@limit).to_a
      former_ids = former_match_survivor_ids(customers.map(&:id))

      customers.map do |customer|
        Result.new(
          customer: customer,
          matched_former_customer: former_ids.include?(customer.id)
        )
      end
    end

    def records
      call.map(&:customer)
    end

    private

    def base_scope
      case @mode
      when :admin_index
        @scope
      when :canonical
        @scope.merge(Customer.canonical)
      else
        @scope.merge(Customer.active).merge(Customer.canonical)
      end
    end

    def matching_customer_ids
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
      binds = {
        pattern: pattern,
        exact_email: Customers::NormalizeContact.email(@query),
        exact_phone: Customers::NormalizeContact.phone(@query)
      }

      direct_ids = Customer.where(match_sql, binds).pluck(:id)

      # Historical browse may surface tombstones as their own rows.
      return direct_ids if @mode == :admin_index

      # Operational / canonical: resolve alias matches to the survivor.
      alias_survivor_ids = Customer.merged.where(match_sql, binds).pluck(:merged_into_customer_id)
      (direct_ids + alias_survivor_ids).uniq
    end

    def match_sql
      <<~SQL.squish
        display_name ILIKE :pattern OR
        given_name ILIKE :pattern OR
        family_name ILIKE :pattern OR
        email ILIKE :pattern OR
        phone ILIKE :pattern OR
        id::text ILIKE :pattern OR
        (email_normalized IS NOT NULL AND email_normalized = :exact_email) OR
        (phone_normalized IS NOT NULL AND phone_normalized = :exact_phone)
      SQL
    end

    def former_match_survivor_ids(survivor_ids)
      return Set.new if @query.blank? || survivor_ids.empty? || @mode == :admin_index

      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
      Customer.merged
        .where(merged_into_customer_id: survivor_ids)
        .where(match_sql, pattern: pattern,
                          exact_email: Customers::NormalizeContact.email(@query),
                          exact_phone: Customers::NormalizeContact.phone(@query))
        .pluck(:merged_into_customer_id)
        .to_set
    end
  end
end
