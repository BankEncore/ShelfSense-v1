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
    @used_klass = merchandise_class(
      code: "used_book",
      pricing_method: "fixed",
      used_merchandise_allowed: true,
      default_standard_department: @standard_dept,
      default_used_department: @used_dept
    )
    @open_klass = merchandise_class(
      code: "open_item",
      pricing_method: "open_price",
      default_standard_department: @standard_dept
    )
    @service_klass = merchandise_class(
      code: "service",
      inventory_mode: "non_inventory",
      pricing_method: "fixed",
      default_standard_department: @standard_dept
    )
    @category = merchandise_category(name: "Fiction", default_merchandise_class: @klass)
    @like_new = merchandise_condition(code: "like_new", price_adjustment_bps: 6_000)
    @product = Products::Create.call(
      attributes: { name: "Example", status: "draft", merchandise_category: @category, list_price_cents: 2_000 },
      actor: @actor,
      identifier_mode: "generate"
    )
  end

  test "draft standard can omit class department and tax when no defaults apply" do
    bare = Products::Create.call(
      attributes: { name: "Bare", status: "draft" },
      actor: @actor,
      identifier_mode: "generate"
    )
    variant = ProductVariants::Create.call(
      product: bare,
      actor: @actor,
      attributes: { variant_type: "standard", status: "draft" }
    )

    assert variant.draft?
    assert variant.standard?
    assert_nil variant.merchandise_condition_id
    assert_nil variant.merchandise_class_id
    assert_nil variant.department_id
    assert_nil variant.tax_class_id
  end

  test "used variant requires condition and standard forbids it" do
    error = assert_raises(ProductVariants::Create::Error) do
      ProductVariants::Create.call(
        product: @product,
        actor: @actor,
        attributes: { variant_type: "used", merchandise_class_id: @used_klass.id }
      )
    end
    assert_match(/merchandise_condition_id is required for used/i, error.message)

    error = assert_raises(ProductVariants::Create::Error) do
      ProductVariants::Create.call(
        product: @product,
        actor: @actor,
        attributes: {
          variant_type: "standard",
          merchandise_condition_id: @like_new.id
        }
      )
    end
    assert_match(/must be blank for standard/i, error.message)
  end

  test "activation requires class department tax and pricing matrix for standard" do
    variant = ProductVariants::Create.call(
      product: @product,
      actor: @actor,
      attributes: {
        variant_type: "standard",
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
        variant_type: "standard",
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

  test "used variant blocked without used_merchandise_allowed" do
    error = assert_raises(ProductVariants::Create::Error) do
      ProductVariants::Create.call(
        product: @product,
        actor: @actor,
        attributes: {
          variant_type: "used",
          merchandise_condition_id: @like_new.id,
          merchandise_class_id: @klass.id,
          department_id: @used_dept.id,
          tax_class_id: @tax.id,
          regular_price_cents: 1_200
        }
      )
    end
    assert_match(/allows used merchandise/i, error.message)
  end

  test "used variant blocked on non_inventory class" do
    error = assert_raises(ProductVariants::Create::Error) do
      ProductVariants::Create.call(
        product: @product,
        actor: @actor,
        attributes: {
          variant_type: "used",
          merchandise_condition_id: @like_new.id,
          merchandise_class_id: @service_klass.id,
          regular_price_cents: 1_200
        }
      )
    end
    assert_match(/non-inventory/i, error.message)
  end

  test "sku is immutable" do
    variant = ProductVariants::Create.call(
      product: @product,
      actor: @actor,
      attributes: { variant_type: "standard" }
    )
    original = variant.sku
    variant.sku = Identifiers::Ean13.complete("221", "999999999")
    assert_not variant.valid?
    assert_includes variant.errors[:sku], "cannot be changed"
    assert_equal original, variant.reload.sku
  end

  test "default resolution uses variant_type for department and price" do
    standard = ProductVariants::Create.call(
      product: @product,
      actor: @actor,
      attributes: { variant_type: "standard" }
    )

    assert_equal @klass.id, standard.merchandise_class_id
    assert_equal @standard_dept.id, standard.department_id
    assert_equal @tax.id, standard.tax_class_id
    assert_equal 2_000, standard.regular_price_cents
    assert_equal "quantity", standard.derived_inventory_tracking

    used = ProductVariants::Create.call(
      product: @product,
      actor: @actor,
      attributes: {
        variant_type: "used",
        merchandise_condition_id: @like_new.id,
        merchandise_class_id: @used_klass.id
      }
    )
    assert_equal @used_dept.id, used.department_id
    assert_equal 1_200, used.regular_price_cents
    assert_equal "individual", used.derived_inventory_tracking
  end

  test "changing class defaults does not mutate existing variants" do
    variant = ProductVariants::Create.call(
      product: @product,
      actor: @actor,
      attributes: { variant_type: "standard" }
    )
    original_dept = variant.department_id
    other = department(code: "other_books", default_tax_class: @tax)
    @klass.update!(default_standard_department: other)

    assert_equal original_dept, variant.reload.department_id
  end

  test "database rejects standard with condition and used without" do
    sku = Identifiers::Ean13.complete("221", "111111111")
    assert_raises(ActiveRecord::StatementInvalid) do
      ProductVariant.insert!({
        id: SecureRandom.uuid_v7,
        product_id: @product.id,
        variant_type: "standard",
        sku: sku,
        merchandise_condition_id: @like_new.id,
        status: "draft",
        lock_version: 0,
        created_at: Time.current,
        updated_at: Time.current
      })
    end

    sku2 = Identifiers::Ean13.complete("221", "222222222")
    assert_raises(ActiveRecord::StatementInvalid) do
      ProductVariant.insert!({
        id: SecureRandom.uuid_v7,
        product_id: @product.id,
        variant_type: "used",
        sku: sku2,
        merchandise_condition_id: nil,
        status: "draft",
        lock_version: 0,
        created_at: Time.current,
        updated_at: Time.current
      })
    end
  end

  test "active variants cannot be saved incomplete" do
    @product.update!(status: "active")
    variant = ProductVariants::Create.call(
      product: @product,
      actor: @actor,
      attributes: {
        variant_type: "standard",
        merchandise_class_id: @klass.id,
        department_id: @standard_dept.id,
        tax_class_id: @tax.id,
        regular_price_cents: 1_999,
        status: "active"
      }
    )

    error = assert_raises(ProductVariants::Update::Error) do
      ProductVariants::Update.call(
        variant: variant,
        actor: @actor,
        attributes: { merchandise_class_id: nil }
      )
    end
    assert_match(/merchandise class/i, error.message)
    assert_equal @klass.id, variant.reload.merchandise_class_id
  end

  test "active used variant with deactivated condition allows unrelated edits" do
    @product.update!(status: "active")
    variant = ProductVariants::Create.call(
      product: @product,
      actor: @actor,
      attributes: {
        variant_type: "used",
        merchandise_condition_id: @like_new.id,
        merchandise_class_id: @used_klass.id,
        department_id: @used_dept.id,
        tax_class_id: @tax.id,
        regular_price_cents: 1_200,
        status: "active"
      }
    )

    @like_new.update!(active: false)
    variant.reload

    assert_not variant.sellable?
    assert variant.update(name: "Still editable")
    assert_equal "Still editable", variant.reload.name

    retired_condition = merchandise_condition(code: "fair", active: false)
    assert_not variant.update(merchandise_condition: retired_condition)
    assert_includes variant.errors[:merchandise_condition_id], "must be an active condition"
  end

  test "used price suggestion uses integer half-up rounding" do
    @product.update!(list_price_cents: 1_005)
    @like_new.update!(price_adjustment_bps: 3_333)
    result = ProductVariants::DefaultResolver.resolve(
      product: @product,
      variant_type: "used",
      condition: @like_new
    )
    # (1005 * 3333 + 5000) / 10000 = 335
    assert_equal 335, result.suggested_price_cents
  end
end
