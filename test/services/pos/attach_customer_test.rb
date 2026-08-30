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

  test "same-customer attach is idempotent while store-credit tender depends on customer" do
    Pos::TenderTypes.seed!
    tax = tax_class(code: "physical_book", name: "Physical book")
    StoreTaxes::Create.call(
      store: @store,
      actor: @actor,
      name: "Illinois State",
      rate_percent: "5.000",
      calculation_order: 1,
      applies_by_tax_class_id: { tax.id => true }
    )
    variant = pos_sellable_variant(actor: @actor, tax_class: tax)
    open_quantity_stock(store: @store, variant: variant, actor: @actor, quantity: 5, unit_cost_cents: 100)
    account = StoredValue::EnsureCustomerAccount.call(customer: @customer, account_type: "store_credit")
    StoredValue::Adjust.call(
      account: account,
      direction: "credit",
      amount_cents: 2_000,
      reason: StoredValueAdjustmentReason.find_by!(code: "goodwill"),
      store: @store,
      performed_by: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    )

    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: variant.sku
    )
    Pos::AttachCustomer.call(
      transaction: transaction.reload,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      customer: @customer
    )
    Pos::AddStoredValueTender.call(
      transaction: transaction.reload,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      tender_type: TenderType.find_by!(code: "store_credit"),
      amount_cents: [ transaction.signed_net_cents, account.reload.balance_cents ].min,
      operation_id: SecureRandom.uuid_v7
    )
    assert Pos::CustomerDependency.dependent_working_stored_value?(transaction.reload)

    Pos::AttachCustomer.call(
      transaction: transaction.reload,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      customer: @customer
    )
    assert_equal @customer.id, transaction.reload.customer_id

    other = Customer.create!(display_name: "Other Customer", email: "other.reg@example.com")
    error = assert_raises(Pos::Error) do
      Pos::AttachCustomer.call(
        transaction: transaction.reload,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        customer: other
      )
    end
    assert_match(/customer-dependent stored-value/, error.message)

    error = assert_raises(Pos::Error) do
      Pos::DetachCustomer.call(
        transaction: transaction.reload,
        actor: @actor,
        expected_lock_version: transaction.lock_version
      )
    end
    assert_match(/customer-dependent stored-value/, error.message)
  end

  test "gift-card issuance alone does not block customer detach" do
    GiftCards::Programs.seed!
    Pos::TenderTypes.seed!
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AttachCustomer.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      customer: @customer
    )
    Pos::AddStoredValueIssuance.call(
      transaction: transaction.reload,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      issuance_type: "activation",
      amount_cents: 1_000,
      gift_card_program: GiftCardProgram.find_by!(code: "generated"),
      operation_id: SecureRandom.uuid_v7
    )
    refute Pos::CustomerDependency.dependent_working_stored_value?(transaction.reload)

    Pos::DetachCustomer.call(
      transaction: transaction.reload,
      actor: @actor,
      expected_lock_version: transaction.lock_version
    )
    assert_nil transaction.reload.customer_id
  end
end
