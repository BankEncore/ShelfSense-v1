# frozen_string_literal: true

require "test_helper"

class ProductVariants::CreateAndActivationTest < ActiveSupport::TestCase
  setup do
    @actor = actor_user
    @tax = tax_class(code: "books")
    @standard_dept = department(code: "new_books", default_tax_class: @tax)
    @used_dept = department(code: "used_books", default_tax_class: @tax)
    @klass = merchandise_class(
      code: "book",
      pricing_method: "fixed",
      used_merchandise_allowed: false,
      default_standard_department: @standard_dept,
      default_used_department: @used_dept
    )
    @open_klass = merchandise_class(
      code: "open_item",
      pricing_method: "open_price",
      default_standard_department: @standard_dept
    )
    @category = merchandise_category(name: "Fiction", default_merchandise_class: @klass)
    @new_condition = merchandise_condition(code: "new", department_basis: "standard")
    @used_condition = merchandise_condition(code: "used", department_basis: "used", price_adjustment_bps: 6_000)
    @product = Products::Create.call(
      attributes: { name: "Example", status: "draft", merchandise_category: @category, list_price_cents: 2_000 },
      actor: @actor,
      identifier_mode: "generate"
    )
  end

  test "draft can omit class department and tax when no defaults apply" do
    bare = Products::Create.call(
      attributes: { name: "Bare", status: "draft" },
      actor: @actor,
      identifier_mode: "generate"
    )
    variant = ProductVariants::Create.call(
      product: bare,
      actor: @actor,
      attributes: { merchandise_condition_id: @new_condition.id, status: "draft" }
    )

    assert variant.draft?
    assert_nil variant.merchandise_class_id
    assert_nil variant.department_id
    assert_nil variant.tax_class_id
  end

  test "condition is required" do
    error = assert_raises(ProductVariants::Create::Error) do
      ProductVariants::Create.call(
        product: @product,
        actor: @actor,
        attributes: { name: "No condition" }
      )
    end
    assert_match(/merchandise_condition_id is required/i, error.message)
  end

  test "activation requires class department tax and pricing matrix" do
    variant = ProductVariants::Create.call(
      product: @product,
      actor: @actor,
      attributes: {
        merchandise_condition_id: @new_condition.id,
        merchandise_class_id: @klass.id,
        department_id: @standard_dept.id,
        tax_class_id: @tax.id,
        regular_price_cents: 1_999,
        status: "draft"
      }
    )

    variant.status = "active"
    assert_not variant.valid?
    assert_includes variant.errors[:product_id], "product must be active"

    @product.update!(status: "active")
    variant.regular_price_cents = nil
    assert_not variant.valid?
    assert_includes variant.errors[:regular_price_cents], "is required for this pricing method"

    variant.regular_price_cents = 1_999
    assert variant.valid?
    assert variant.save
  end

  test "open_price activation may leave regular price null" do
    @product.update!(status: "active")
    variant = ProductVariants::Create.call(
      product: @product,
      actor: @actor,
      attributes: {
        merchandise_condition_id: @new_condition.id,
        merchandise_class_id: @open_klass.id,
        department_id: @standard_dept.id,
        tax_class_id: @tax.id,
        regular_price_cents: nil,
        status: "draft"
      }
    )

    variant.status = "active"
    assert_nil variant.regular_price_cents
    assert variant.valid?
  end

  test "used condition is blocked unless class allows used merchandise" do
    @product.update!(status: "active")
    variant = ProductVariants::Create.call(
      product: @product,
      actor: @actor,
      attributes: {
        merchandise_condition_id: @used_condition.id,
        merchandise_class_id: @klass.id,
        department_id: @used_dept.id,
        tax_class_id: @tax.id,
        regular_price_cents: 1_200,
        status: "draft"
      }
    )

    variant.status = "active"
    assert_not variant.valid?
    assert_includes variant.errors[:base], "condition is not allowed for this merchandise class"

    allowed = merchandise_class(
      code: "used_book",
      used_merchandise_allowed: true,
      default_standard_department: @standard_dept,
      default_used_department: @used_dept
    )
    variant.merchandise_class = allowed
    assert variant.valid?
  end

  test "sku is immutable" do
    variant = ProductVariants::Create.call(
      product: @product,
      actor: @actor,
      attributes: { merchandise_condition_id: @new_condition.id }
    )
    original = variant.sku
    variant.sku = Identifiers::Ean13.complete("221", "999999999")
    assert_not variant.valid?
    assert_includes variant.errors[:sku], "cannot be changed"
    assert_equal original, variant.reload.sku
  end

  test "default resolution fills class department tax and suggested price" do
    variant = ProductVariants::Create.call(
      product: @product,
      actor: @actor,
      attributes: { merchandise_condition_id: @new_condition.id }
    )

    assert_equal @klass.id, variant.merchandise_class_id
    assert_equal @standard_dept.id, variant.department_id
    assert_equal @tax.id, variant.tax_class_id
    assert_equal 2_000, variant.regular_price_cents

    used_variant = ProductVariants::Create.call(
      product: @product,
      actor: @actor,
      attributes: { merchandise_condition_id: @used_condition.id }
    )
    assert_equal @used_dept.id, used_variant.department_id
    assert_equal 1_200, used_variant.regular_price_cents
  end
end
