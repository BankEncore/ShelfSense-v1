# frozen_string_literal: true

require "test_helper"

module Customers
  class MergeCustomersTest < ActiveSupport::TestCase
    setup do
      @bootstrap = bootstrap!
      @store = @bootstrap[:store]
      @actor = @bootstrap[:administrator]
      Inventory::AdjustmentReasons.seed!
      @tax = tax_class(code: "merge_tax_#{SecureRandom.hex(2)}")
      @variant = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Merge Book")
      open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 2, unit_cost_cents: 100)

      @survivor = Customer.create!(display_name: "Survivor", email: "survivor@example.com", phone: "555-100-0000", notes: "keep me")
      @source = Customer.create!(display_name: "Source", email: "source@example.com", phone: "555-200-0000", notes: "alias notes")
    end

    test "happy path reassigns active requests and tombstones source" do
      request = Customers::CreateRequest.call(
        store: @store, customer: @source, product_variant: @variant, actor: @actor
      )

      result = Customers::MergeCustomers.call(
        source: @source,
        survivor: @survivor,
        actor: @actor,
        reason: "same person",
        idempotency_key: SecureRandom.uuid_v7,
        store: @store
      )

      assert_not result.replayed
      assert @source.reload.merged?
      assert_equal @survivor.id, @source.merged_into_customer_id
      assert_not @source.active?
      assert_equal @survivor.id, request.reload.customer_id
      assert_equal 1, result.requests_reassigned_count
      assert_equal "keep me", @survivor.reload.notes
      assert_equal "alias notes", @source.notes
      assert AuditEvent.exists?(action: "customers.merge", subject_id: @survivor.id)
    end

    test "flattens existing aliases onto new survivor" do
      mid = Customer.create!(display_name: "Mid", email: "mid@example.com", phone: "555-300-0000")
      Customers::MergeCustomers.call(
        source: @source,
        survivor: mid,
        actor: @actor,
        reason: "first merge",
        idempotency_key: SecureRandom.uuid_v7
      )

      Customers::MergeCustomers.call(
        source: mid,
        survivor: @survivor,
        actor: @actor,
        reason: "second merge",
        idempotency_key: SecureRandom.uuid_v7
      )

      assert_equal @survivor.id, @source.reload.merged_into_customer_id
      assert_equal @survivor.id, mid.reload.merged_into_customer_id
      assert @survivor.reload.canonical?
    end

    test "preserves completed and cancelled request customer_id" do
      active = Customers::CreateRequest.call(
        store: @store, customer: @source, product_variant: @variant, actor: @actor
      )
      completed = CustomerRequest.create!(
        store: @store,
        number: StoreDocumentSequence.next_number!(store: @store, document_kind: "customer_request"),
        customer: @source,
        product_variant: @variant,
        requested_quantity: 1,
        status: "completed",
        completed_at: Time.current
      )
      cancelled = CustomerRequest.create!(
        store: @store,
        number: StoreDocumentSequence.next_number!(store: @store, document_kind: "customer_request"),
        customer: @source,
        product_variant: @variant,
        requested_quantity: 1,
        status: "cancelled",
        cancelled_at: Time.current,
        cancelled_by: @actor,
        cancellation_reason: "test"
      )

      Customers::MergeCustomers.call(
        source: @source,
        survivor: @survivor,
        actor: @actor,
        reason: "cleanup",
        idempotency_key: SecureRandom.uuid_v7
      )

      assert_equal @survivor.id, active.reload.customer_id
      assert_equal @source.id, completed.reload.customer_id
      assert_equal @source.id, cancelled.reload.customer_id
    end

    test "rejects self merge and already merged source" do
      error = assert_raises(Customers::Error) do
        Customers::MergeCustomers.call(
          source: @survivor,
          survivor: @survivor,
          actor: @actor,
          reason: "noop",
          idempotency_key: SecureRandom.uuid_v7
        )
      end
      assert_match(/itself/, error.message)

      Customers::MergeCustomers.call(
        source: @source,
        survivor: @survivor,
        actor: @actor,
        reason: "done",
        idempotency_key: SecureRandom.uuid_v7
      )
      error = assert_raises(Customers::Error) do
        Customers::MergeCustomers.call(
          source: @source,
          survivor: @survivor,
          actor: @actor,
          reason: "again",
          idempotency_key: SecureRandom.uuid_v7
        )
      end
      assert_match(/already merged/, error.message)
    end

    test "idempotent replay returns stored outcome" do
      key = SecureRandom.uuid_v7
      first = Customers::MergeCustomers.call(
        source: @source,
        survivor: @survivor,
        actor: @actor,
        reason: "dup",
        idempotency_key: key
      )
      second = Customers::MergeCustomers.call(
        source: @source,
        survivor: @survivor,
        actor: @actor,
        reason: "dup",
        idempotency_key: key
      )
      assert second.replayed
      assert_equal first.survivor.id, second.survivor.id
    end

    test "payload mismatch on changed survivor or reason" do
      key = SecureRandom.uuid_v7
      Customers::MergeCustomers.call(
        source: @source,
        survivor: @survivor,
        actor: @actor,
        reason: "dup",
        idempotency_key: key
      )
      other = Customer.create!(display_name: "Other", email: "other@example.com", phone: "555-400-0000")
      assert_raises(Idempotency::OperationService::PayloadMismatchError) do
        Customers::MergeCustomers.call(
          source: @source,
          survivor: other,
          actor: @actor,
          reason: "dup",
          idempotency_key: key
        )
      end
      assert_raises(Idempotency::OperationService::PayloadMismatchError) do
        Customers::MergeCustomers.call(
          source: @source,
          survivor: @survivor,
          actor: @actor,
          reason: "different reason",
          idempotency_key: key
        )
      end
    end

    test "create request against merged alias resolves to survivor" do
      Customers::MergeCustomers.call(
        source: @source,
        survivor: @survivor,
        actor: @actor,
        reason: "dup",
        idempotency_key: SecureRandom.uuid_v7
      )
      request = Customers::CreateRequest.call(
        store: @store,
        customer: @source.reload,
        product_variant: @variant,
        actor: @actor
      )
      assert_equal @survivor.id, request.customer_id
    end

    test "create request requires contact" do
      bare = Customer.create!(display_name: "Bare")
      error = assert_raises(Customers::Error) do
        Customers::CreateRequest.call(
          store: @store,
          customer: bare,
          product_variant: @variant,
          actor: @actor
        )
      end
      assert_match(/email or phone/, error.message)
    end
  end
end
