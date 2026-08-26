# frozen_string_literal: true

require "test_helper"

class PosCustomerAttachTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    @tax = tax_class(code: "physical_book", name: "Physical book")
    StoreTaxes::Create.call(
      store: @store,
      actor: @actor,
      name: "Illinois State",
      rate_percent: "5.000",
      calculation_order: 1,
      applies_by_tax_class_id: { @tax.id => true }
    )
    @variant = pos_sellable_variant(actor: @actor, tax_class: @tax)
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 5)
    @register = Register.create!(store: @store, register_number: 1, name: "Front")
    @customer = Customer.create!(display_name: "Attachable Reader", email: "attachable@example.com")
    sign_in_as("admin")
  end

  test "search attach and detach a customer on a working ticket" do
    post pos_register_enter_path, params: enter_params
    follow_redirect!
    transaction = PosTransaction.working.find_by!(register: @register)

    get pos_register_customer_search_path, params: { register_id: @register.id, q: "Attachable" }
    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal @customer.id, payload.fetch("results").first.fetch("id")

    post pos_register_attach_customer_path, params: {
      register_id: @register.id,
      lock_version: transaction.lock_version,
      customer_id: @customer.id
    }
    assert_response :success
    assert_equal @customer.id, transaction.reload.customer_id
    assert_match "Attachable Reader", response.body

    post pos_register_detach_customer_path, params: {
      register_id: @register.id,
      lock_version: transaction.lock_version
    }
    assert_response :success
    assert_nil transaction.reload.customer_id
  end

  test "customer search omits inactive customers and attach rejects them" do
    inactive = Customer.create!(display_name: "Inactive Attach", email: "inactive.attach@example.com", active: false)
    post pos_register_enter_path, params: enter_params
    follow_redirect!
    transaction = PosTransaction.working.find_by!(register: @register)

    get pos_register_customer_search_path, params: { register_id: @register.id, q: "Inactive Attach" }
    payload = JSON.parse(response.body)
    assert_empty payload.fetch("results")

    post pos_register_attach_customer_path, params: {
      register_id: @register.id,
      lock_version: transaction.lock_version,
      customer_id: inactive.id
    }
    assert_match(/active canonical customer/, response.body)
    assert_nil transaction.reload.customer_id
  end

  test "completed ticket and receipt show the attached customer name" do
    post pos_register_enter_path, params: enter_params
    follow_redirect!
    transaction = PosTransaction.working.find_by!(register: @register)
    post pos_register_merchandise_path, params: { identifier: @variant.sku, lock_version: transaction.lock_version }
    post pos_register_attach_customer_path, params: {
      register_id: @register.id,
      lock_version: transaction.reload.lock_version,
      customer_id: @customer.id
    }
    post pos_register_tender_path, params: { tender_amount: "25.00", lock_version: transaction.reload.lock_version }
    operation_id = css_select("input[name='completion_operation_id']").first["value"]
    post pos_transaction_complete_path(transaction), params: {
      completion_operation_id: operation_id,
      lock_version: transaction.reload.lock_version,
      expected_total_cents: transaction.total_cents,
      expected_signed_net_cents: transaction.signed_net_cents,
      amount_presented_cents: 2500
    }
    follow_redirect!
    assert_match "Customer · Attachable Reader", response.body
    assert_match "Customer: Attachable Reader", response.body

    receipt = Pos::CustomerReceipt.build(transaction.reload)
    assert_equal "Attachable Reader", receipt.customer_name
  end

  test "store-credit tender still requires an attached customer" do
    Pos::TenderTypes.seed!
    account = StoredValue::OpenAccount.call(account_type: "store_credit", customer: @customer)
    StoredValue::Post.call(
      operation_type: "issue",
      store: @store,
      performed_by: @actor,
      source_id: account.id,
      idempotency_key: SecureRandom.uuid_v7,
      entries: [ { account: account, amount_cents: 5000 } ]
    )
    post pos_register_enter_path, params: enter_params
    follow_redirect!
    transaction = PosTransaction.working.find_by!(register: @register)
    post pos_register_merchandise_path, params: { identifier: @variant.sku, lock_version: transaction.lock_version }
    store_credit = TenderType.find_by!(code: "store_credit")
    post pos_register_tender_path, params: {
      tender_amount: "5.00",
      lock_version: transaction.reload.lock_version,
      tender_type_id: store_credit.id
    }
    assert_match(/customer is required/, response.body)
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end

  def enter_params
    {
      register_id: @register.id,
      opening_float: "50.00",
      confirmed_business_date: BusinessDate.for_store(@store).iso8601
    }
  end
end
