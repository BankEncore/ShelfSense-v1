# frozen_string_literal: true

require "test_helper"

class PosProductTargetingTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    @tax = tax_class(code: "physical_book", name: "Physical book")
    @context = pos_open_context(store: @store, actor: @actor)
  end

  test "product primary identifier with one sellable variant is addable" do
    variant = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "One Variant")
    open_quantity_stock(store: @store, variant: variant, actor: @actor, quantity: 3)

    result = resolve(variant.product.primary_identifier)

    assert_equal :addable_variant, result.outcome
    assert_equal variant.id, result.variant.id
  end

  test "product industry identifier enters the same POS product path as the 222" do
    variant = pos_sellable_variant(
      actor: @actor,
      tax_class: @tax,
      name: "Industry Book",
      industry_identifier: external_isbn13
    )
    open_quantity_stock(store: @store, variant: variant, actor: @actor, quantity: 3)

    result = resolve(variant.product.industry_identifier)

    assert_equal :addable_variant, result.outcome
    assert_equal variant.id, result.variant.id
  end

  test "a unique lookup code with one POS-eligible variant advances like a product primary" do
    variant = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Coded Book", lookup_code: "SHELF-A1")
    open_quantity_stock(store: @store, variant: variant, actor: @actor, quantity: 3)

    result = resolve("shelf-a1")

    assert_equal :addable_variant, result.outcome
    assert_equal variant.id, result.variant.id
  end

  test "a unique lookup code with several POS-eligible variants uses the variant chooser" do
    first = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Two Variants", lookup_code: "TWO")
    second = pos_sellable_variant(actor: @actor, tax_class: @tax, product: first.product)
    open_quantity_stock(store: @store, variant: first, actor: @actor, quantity: 2)
    open_quantity_stock(store: @store, variant: second, actor: @actor, quantity: 2)

    result = resolve("two")

    assert_equal :variant_choice_required, result.outcome
    assert_equal [ first.id, second.id ].sort, result.variants.map(&:id).sort
    assert_equal first.product.id, result.product.id
  end

  test "a unique lookup code whose variant is individually tracked uses the unit chooser" do
    used, unit = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax, name: "Coded Used")
    used.product.update!(lookup_code: "USED-1")

    result = resolve("used-1")

    assert_equal :unit_choice_required, result.outcome
    assert_equal used.id, result.variant.id
    assert_equal [ unit.id ], result.units.map(&:id)
  end

  test "a shared lookup code requires product selection and never picks the first product" do
    first = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Alpha Shared", lookup_code: "SHARED")
    second = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Beta Shared", lookup_code: "SHARED")
    open_quantity_stock(store: @store, variant: first, actor: @actor, quantity: 2)
    open_quantity_stock(store: @store, variant: second, actor: @actor, quantity: 2)

    result = resolve("shared")

    assert_equal :product_choice_required, result.outcome
    assert_equal [ first.product.id, second.product.id ].sort, result.products.map(&:id).sort
    assert_nil result.variant
  end

  test "cancelling product selection adds nothing and a shared code cannot be added directly" do
    first = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Alpha Shared", lookup_code: "SHARED")
    pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Beta Shared", lookup_code: "SHARED")
    open_quantity_stock(store: @store, variant: first, actor: @actor, quantity: 2)

    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    lock = transaction.lock_version

    error = assert_raises(Pos::Error) do
      Pos::AddMerchandise.call(
        transaction: transaction,
        actor: @actor,
        expected_lock_version: lock,
        identifier: "SHARED"
      )
    end

    assert_equal "identifier matches multiple products", error.message
    transaction.reload
    assert_equal lock, transaction.lock_version
    assert_equal 0, transaction.pos_transaction_lines.count
  end

  test "selecting a product re-applies POS eligibility for that product" do
    first = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Alpha Shared", lookup_code: "SHARED")
    pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Beta Shared", lookup_code: "SHARED")
    open_quantity_stock(store: @store, variant: first, actor: @actor, quantity: 2)

    result = Pos::ResolveMerchandiseForSale.call(store: @store, product: first.product)

    assert_equal :addable_variant, result.outcome
    assert_equal first.id, result.variant.id
  end

  test "a product identifier with no POS-eligible variant is unavailable" do
    product = Products::Create.call(
      attributes: { name: "No Variants", status: "active" },
      actor: @actor,
      lookup_code: "EMPTY"
    )

    assert_equal :unavailable, resolve(product.primary_identifier).outcome
    assert_equal :unavailable, resolve("empty").outcome
  end

  test "a retired product identifier does not fall through to an identical lookup code" do
    variant = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Retired Code")
    open_quantity_stock(store: @store, variant: variant, actor: @actor, quantity: 2)
    other = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Decoy")
    other.product.update!(lookup_code: variant.product.primary_identifier)
    Identifiers::Registry.retire!(value: variant.product.primary_identifier)

    result = resolve(variant.product.primary_identifier)

    assert_equal :unavailable, result.outcome
    assert_nil result.variant
  end

  private

  def resolve(identifier)
    Pos::ResolveMerchandiseForSale.call(store: @store, identifier: identifier)
  end
end
