# frozen_string_literal: true

require "test_helper"

class Idempotency::OperationServiceTest < ActiveSupport::TestCase
  setup do
    @source_id = SecureRandom.uuid_v7
    @key = SecureRandom.uuid_v7
    @payload = { store_id: "a", quantity: 1 }
  end

  test "completed operation replays" do
    first = Idempotency::OperationService.begin!(
      source_id: @source_id,
      operation_type: "post_inventory_adjustment",
      idempotency_key: @key,
      payload: @payload
    )
    result_id = SecureRandom.uuid_v7
    Idempotency::OperationService.complete!(
      first.operation,
      result_type: "InventoryAdjustment",
      result_id: result_id
    )

    second = Idempotency::OperationService.begin!(
      source_id: @source_id,
      operation_type: "post_inventory_adjustment",
      idempotency_key: @key,
      payload: @payload
    )
    assert second.replayed
    assert_equal result_id, second.operation.result_id
  end

  test "in_flight with valid lease is rejected" do
    Idempotency::OperationService.begin!(
      source_id: @source_id,
      operation_type: "post_inventory_adjustment",
      idempotency_key: @key,
      payload: @payload
    )

    error = assert_raises(Idempotency::OperationService::Error) do
      Idempotency::OperationService.begin!(
        source_id: @source_id,
        operation_type: "post_inventory_adjustment",
        idempotency_key: @key,
        payload: @payload
      )
    end
    assert_match(/still in flight/i, error.message)
  end

  test "expired in_flight lease is reclaimed" do
    first = Idempotency::OperationService.begin!(
      source_id: @source_id,
      operation_type: "post_inventory_adjustment",
      idempotency_key: @key,
      payload: @payload
    )
    first.operation.update_columns(lease_expires_at: 3.minutes.ago)

    second = Idempotency::OperationService.begin!(
      source_id: @source_id,
      operation_type: "post_inventory_adjustment",
      idempotency_key: @key,
      payload: @payload
    )
    assert_not second.replayed
    assert_equal "in_flight", second.operation.status
    assert second.operation.lease_expires_at > Time.current
  end

  test "failed operation with same payload may retry" do
    first = Idempotency::OperationService.begin!(
      source_id: @source_id,
      operation_type: "post_inventory_adjustment",
      idempotency_key: @key,
      payload: @payload
    )
    Idempotency::OperationService.fail!(first.operation, message: "boom")

    second = Idempotency::OperationService.begin!(
      source_id: @source_id,
      operation_type: "post_inventory_adjustment",
      idempotency_key: @key,
      payload: @payload
    )
    assert_not second.replayed
    assert_equal "in_flight", second.operation.status
    assert_nil second.operation.error_message
  end

  test "payload mismatch remains an error after failure" do
    first = Idempotency::OperationService.begin!(
      source_id: @source_id,
      operation_type: "post_inventory_adjustment",
      idempotency_key: @key,
      payload: @payload
    )
    Idempotency::OperationService.fail!(first.operation, message: "boom")

    assert_raises(Idempotency::OperationService::PayloadMismatchError) do
      Idempotency::OperationService.begin!(
        source_id: @source_id,
        operation_type: "post_inventory_adjustment",
        idempotency_key: @key,
        payload: { store_id: "b", quantity: 2 }
      )
    end
  end

  test "stale worker complete! after lease takeover raises StaleObjectError" do
    first = Idempotency::OperationService.begin!(
      source_id: @source_id,
      operation_type: "post_inventory_adjustment",
      idempotency_key: @key,
      payload: @payload
    )
    stale = first.operation
    stale.update_columns(lease_expires_at: 3.minutes.ago)

    takeover = Idempotency::OperationService.begin!(
      source_id: @source_id,
      operation_type: "post_inventory_adjustment",
      idempotency_key: @key,
      payload: @payload
    )
    assert_not takeover.replayed
    assert_operator takeover.operation.lock_version, :>, stale.lock_version

    assert_raises(ActiveRecord::StaleObjectError) do
      Idempotency::OperationService.complete!(
        stale,
        result_type: "InventoryAdjustment",
        result_id: SecureRandom.uuid_v7
      )
    end
  end
end
