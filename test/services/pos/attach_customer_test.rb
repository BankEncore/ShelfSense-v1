# frozen_string_literal: true

require "test_helper"

class PosAttachCustomerTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    @context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 10_000)
    @customer = Customer.create!(display_name: "Register Customer", email: "register.customer@example.com")
  end

  test "attaches an active canonical customer and detach clears it" do
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)

    Pos::AttachCustomer.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      customer: @customer
    )
    assert_equal @customer.id, transaction.reload.customer_id

    Pos::DetachCustomer.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version
    )
    assert_nil transaction.reload.customer_id
  end

  test "rejects inactive and merged customers" do
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    inactive = Customer.create!(display_name: "Inactive Register", email: "inactive.reg@example.com", active: false)
    error = assert_raises(Pos::Error) do
      Pos::AttachCustomer.call(
        transaction: transaction,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        customer: inactive
      )
    end
    assert_match(/active canonical customer/, error.message)

    survivor = Customer.create!(display_name: "Survivor Register", email: "surv.reg@example.com")
    source = Customer.create!(display_name: "Source Register", email: "src.reg@example.com")
    Customers::MergeCustomers.call(
      source: source,
      survivor: survivor,
      actor: @actor,
      reason: "dup",
      idempotency_key: SecureRandom.uuid_v7,
      store: @store
    )
    error = assert_raises(Pos::Error) do
      Pos::AttachCustomer.call(
        transaction: transaction,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        customer: source.reload
      )
    end
    assert_match(/active canonical customer/, error.message)
  end
end
