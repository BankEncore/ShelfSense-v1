# frozen_string_literal: true

require "test_helper"

module Customers
  class CreateTest < ActiveSupport::TestCase
    setup do
      @bootstrap = bootstrap!
      @store = @bootstrap[:store]
      @actor = @bootstrap[:administrator]
      @source_id = SecureRandom.uuid_v7
    end

    test "creates a canonical customer with audit and no stored-value account" do
      key = SecureRandom.uuid_v7

      result = Customers::Create.call(
        display_name: "Quick Created Reader",
        email: "quick.created@example.com",
        actor: @actor,
        store: @store,
        idempotency_key: key,
        source_id: @source_id
      )

      assert_not result.replayed
      customer = result.customer
      assert customer.persisted?
      assert_equal "Quick Created Reader", customer.display_name
      assert AuditEvent.exists?(action: "customers.create", subject_id: customer.id)
      assert_empty StoredValueAccount.where(customer_id: customer.id)
    end

    test "idempotent replay returns the same customer without a second audit" do
      key = SecureRandom.uuid_v7
      attrs = {
        display_name: "Replay Reader",
        email: "replay.reader@example.com",
        actor: @actor,
        store: @store,
        idempotency_key: key,
        source_id: @source_id
      }

      first = Customers::Create.call(**attrs)
      second = Customers::Create.call(**attrs)

      assert_not first.replayed
      assert second.replayed
      assert_equal first.customer.id, second.customer.id
      assert_equal 1, Customer.where(display_name: "Replay Reader").count
      assert_equal 1, AuditEvent.where(action: "customers.create", subject_id: first.customer.id).count
    end

    test "duplicate candidates block create until acknowledged" do
      Customer.create!(display_name: "Existing Reader", email: "dup.create@example.com", phone: "555-900-1000")
      key = SecureRandom.uuid_v7

      error = assert_raises(Customers::DuplicateFoundError) do
        Customers::Create.call(
          display_name: "Another Reader",
          email: "dup.create@example.com",
          actor: @actor,
          store: @store,
          idempotency_key: key,
          source_id: @source_id
        )
      end
      assert error.suggestions.any?
      assert_nil Customer.find_by(display_name: "Another Reader")

      result = Customers::Create.call(
        display_name: "Another Reader",
        email: "dup.create@example.com",
        actor: @actor,
        store: @store,
        idempotency_key: SecureRandom.uuid_v7,
        source_id: @source_id,
        acknowledge_duplicates: true
      )
      assert result.customer.persisted?
    end

    test "require_contact rejects missing email and phone for contextual credit flows" do
      key = SecureRandom.uuid_v7

      error = assert_raises(Customers::Error) do
        Customers::Create.call(
          display_name: "No Contact Reader",
          actor: @actor,
          store: @store,
          idempotency_key: key,
          source_id: @source_id,
          require_contact: true
        )
      end
      assert_match(/email or phone/i, error.message)
    end
  end
end
