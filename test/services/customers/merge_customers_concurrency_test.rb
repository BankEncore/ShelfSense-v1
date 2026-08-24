# frozen_string_literal: true

require "test_helper"

module Customers
  class MergeCustomersConcurrencyTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    setup do
      @actor = User.find_by(username: "admin")
      unless @actor
        bootstrap = bootstrap!
        @actor = bootstrap[:administrator]
      end
      Authorization::PermissionCatalog.seed!(granted_by: @actor)
      @suffix = SecureRandom.hex(4)
      @a = Customer.create!(display_name: "A #{@suffix}", email: "a_#{@suffix}@example.com", phone: "555-111-0001")
      @b = Customer.create!(display_name: "B #{@suffix}", email: "b_#{@suffix}@example.com", phone: "555-111-0002")
      @c = Customer.create!(display_name: "C #{@suffix}", email: "c_#{@suffix}@example.com", phone: "555-111-0003")
    end

    teardown do
      conn = ActiveRecord::Base.connection
      tables = conn.tables - %w[schema_migrations ar_internal_metadata]
      conn.disable_referential_integrity do
        tables.each { |table| conn.execute("TRUNCATE TABLE #{conn.quote_table_name(table)} CASCADE") }
      end
    end

    test "concurrent A→B and B→C never leave an alias chain" do
      errors = Array.new(2)
      threads = [
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            Customers::MergeCustomers.call(
              source: @a,
              survivor: @b,
              actor: @actor,
              reason: "concurrent A to B",
              idempotency_key: SecureRandom.uuid_v7
            )
          rescue StandardError => e
            errors[0] = e
          end
        end,
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            Customers::MergeCustomers.call(
              source: @b,
              survivor: @c,
              actor: @actor,
              reason: "concurrent B to C",
              idempotency_key: SecureRandom.uuid_v7
            )
          rescue StandardError => e
            errors[1] = e
          end
        end
      ]
      threads.each { |thread| assert thread.join(30), "thread did not finish (possible deadlock)" }

      assert errors.none? { |error| error.is_a?(ActiveRecord::Deadlocked) }, errors.inspect

      @a.reload
      @b.reload
      @c.reload

      merged = [ @a, @b, @c ].select(&:merged?)
      assert_operator merged.size, :>=, 1

      merged.each do |customer|
        survivor = Customer.find(customer.merged_into_customer_id)
        assert survivor.canonical?,
               "alias #{customer.id} points at merged #{survivor.id} (forbidden chain)"
      end

      # At most one hop from any row to a canonical survivor.
      [ @a, @b, @c ].each do |customer|
        next unless customer.merged?

        assert_equal customer.merged_into_customer_id, customer.canonical.id
      end
    end
  end
end
