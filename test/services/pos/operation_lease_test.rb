# frozen_string_literal: true

require "test_helper"

class Pos::OperationLeaseTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @register = Register.create!(store: @store, register_number: 1, name: "Front")
    @other = Register.create!(store: @store, register_number: 2, name: "Back")
    @operation_id = SecureRandom.uuid_v7
    @payload = {
      "transaction_id" => SecureRandom.uuid_v7,
      "operation_id" => @operation_id,
      "expected_lock_version" => 0,
      "expected_total_cents" => 100,
      "amount_presented_cents" => 100
    }
  end

  test "same operation_id reused against another register fails explicitly" do
    Pos::OperationLease.begin!(
      register_id: @register.id,
      operation_id: @operation_id,
      command_payload: @payload,
      store_id: @store.id,
      pos_transaction_id: nil
    )

    error = assert_raises(Pos::OperationLease::Error) do
      Pos::OperationLease.begin!(
        register_id: @other.id,
        operation_id: @operation_id,
        command_payload: @payload,
        store_id: @store.id,
        pos_transaction_id: nil
      )
    end
    assert_match(/another register/, error.message)
  end
end
