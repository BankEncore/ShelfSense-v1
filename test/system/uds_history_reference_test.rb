# frozen_string_literal: true

require "application_system_test_case"

class UdsHistoryReferenceTest < ApplicationSystemTestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    @tax = tax_class(code: "uds_hist_#{SecureRandom.hex(3)}", name: "UDS history tax")
    StoreTaxes::Create.call(
      store: @store,
      actor: @actor,
      name: "UDS State",
      rate_percent: "5.000",
      calculation_order: 1,
      applies_by_tax_class_id: { @tax.id => true }
    )
    @variant = pos_sellable_variant(actor: @actor, tax_class: @tax)
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 5)
    @register = Register.create!(store: @store, register_number: 99, name: "UDS Front")
    @context = pos_open_context(store: @store, actor: @actor, register: @register)
    @transaction = complete_cash_sale!
    sign_in_admin(actor: @actor)
  end

  test "transaction history index passes axe and layout smoke" do
    visit pos_transactions_path
    assert_text @transaction.transaction_reference
    assert_axe_clean(surface: :transaction_history)
    uds_layout_smoke(surface: :transaction_history, scroll_selector: ".table-scroll")
    assert_reduced_motion_smoke(surface: :transaction_history)
    assert_forced_colors_smoke(surface: :transaction_history)
  end

  test "transaction detail passes axe" do
    visit pos_transaction_path(@transaction)
    assert_text "Example Book"
    assert_axe_clean(surface: :transaction_history)
  end

  private

  def complete_cash_sale!
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku
    )
    transaction.reload
    Pos::TenderCash.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: transaction.total_cents
    )
    transaction.reload
    Pos::CompleteTransaction.call(
      transaction: transaction,
      actor: @actor,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents
    )
    transaction.reload
  end
end
