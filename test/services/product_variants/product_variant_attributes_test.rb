# frozen_string_literal: true

require "test_helper"

class ProductVariantAttributesTest < ActiveSupport::TestCase
  include Phase2Fixtures

  setup do
    @actor = actor_user
    Authorization::PermissionCatalog.seed!(granted_by: @actor)
    @tax = tax_class(code: "pva_tax")
    @dept = department(code: "pva_dept")
    @klass = merchandise_class(code: "pva_std", department: @dept, default_tax_class: @tax, pricing_method: "fixed")
    @used_klass = merchandise_class(
      code: "pva_used",
      department: @dept,
      default_tax_class: @tax,
      pricing_method: "fixed",
      used_merchandise_allowed: true
    )
    @condition = merchandise_condition(code: "pva_ln", name: "Like New")
    @category = merchandise_category(
      name: "PVA Cat",
      default_standard_merchandise_class: @klass,
      default_used_merchandise_class: @used_klass
    )
  end

  test "rejects attribute 2 without attribute 1 and duplicate labels" do
    error = assert_raises(Products::Create::Error) do
      Products::Create.call(
        attributes: { name: "Labels", status: "draft", variant_option_name_2: "Color" },
        actor: @actor
      )
    end
    assert_match(/Attribute 1/i, error.message)
  end

  test "trims labels and rejects normalized duplicates" do
    error = assert_raises(Products::Create::Error) do
      Products::Create.call(
        attributes: {
          name: "Dup labels",
          status: "draft",
          variant_option_name_1: " Color ",
          variant_option_name_2: "color"
        },
        actor: @actor
      )
    end
    assert_match(/differ/i, error.message)

    product = Products::Create.call(
      attributes: {
        name: "Trimmed",
        status: "draft",
        variant_option_name_1: " Size "
      },
      actor: @actor
    )
    assert_equal "Size", product.variant_option_name_1
  end

  test "structural add or remove rejected when variants exist; rename allowed" do
    product = Products::Create.call(
      attributes: { name: "Has variant", status: "active", merchandise_category: @category },
      actor: @actor
    )
    ProductVariants::Create.call(
      product: product,
      actor: @actor,
      attributes: { variant_type: "standard", status: "draft", regular_price_cents: 1000 }
    )

    error = assert_raises(Products::Update::Error) do
      Products::Update.call(
        product: product,
        actor: @actor,
        attributes: { variant_option_name_1: "Size" }
      )
    end
    assert_match(/cannot add or remove/i, error.message)

    attributed = Products::Create.call(
      attributes: {
        name: "Attributed empty",
        status: "active",
        variant_option_name_1: "Colour",
        merchandise_category: @category
      },
      actor: @actor
    )
    ProductVariants::Create.call(
      product: attributed,
      actor: @actor,
      attributes: {
        variant_type: "standard",
        status: "draft",
        option_value_1: "Red",
        regular_price_cents: 1000
      }
    )
    Products::Update.call(
      product: attributed,
      actor: @actor,
      attributes: { variant_option_name_1: "Color" }
    )
    assert_equal "Color", attributed.reload.variant_option_name_1
    assert_equal "Red", attributed.product_variants.first.option_value_1
  end

  test "attributed product create does not create a placeholder variant" do
    product = Products::Create.call(
      attributes: {
        name: "Tee",
        status: "active",
        variant_option_name_1: "Size",
        merchandise_category: @category
      },
      actor: @actor
    )
    assert product.attributed?
    assert_equal 0, product.product_variants.count
  end

  test "omitted status defaults to active for product and variant" do
    product = Products::Create.call(
      attributes: { name: "Active default", merchandise_category: @category, list_price_cents: 1500 },
      actor: @actor
    )
    assert_equal "active", product.status

    variant = ProductVariants::Create.call(
      product: product,
      actor: @actor,
      attributes: { variant_type: "standard", regular_price_cents: 1500 }
    )
    assert_equal "active", variant.status
    assert_equal "Standard", variant.name
  end

  test "configured attribute values required on persist and uniqueness is enforced" do
    product = Products::Create.call(
      attributes: {
        name: "Sized",
        status: "active",
        variant_option_name_1: "Size",
        merchandise_category: @category,
        list_price_cents: 2000
      },
      actor: @actor
    )

    error = assert_raises(ProductVariants::Create::Error) do
      ProductVariants::Create.call(
        product: product,
        actor: @actor,
        attributes: { variant_type: "standard", status: "draft", regular_price_cents: 2000 }
      )
    end
    assert_match(/option value 1/i, error.message)

    first = ProductVariants::Create.call(
      product: product,
      actor: @actor,
      attributes: {
        variant_type: "standard",
        status: "draft",
        option_value_1: "M",
        regular_price_cents: 2000
      }
    )
    assert_equal "M", first.name
    assert_equal "m", first.option_value_1_normalized

    error = assert_raises(ProductVariants::Create::Error) do
      ProductVariants::Create.call(
        product: product,
        actor: @actor,
        attributes: {
          variant_type: "standard",
          status: "draft",
          option_value_1: " m ",
          regular_price_cents: 2000
        }
      )
    end
    assert_match(/already exists/i, error.message)

    second_condition = merchandise_condition(code: "pva_gd", name: "Good")
    used_a = ProductVariants::Create.call(
      product: product,
      actor: @actor,
      attributes: {
        variant_type: "used",
        status: "draft",
        merchandise_condition_id: @condition.id,
        merchandise_class_id: @used_klass.id,
        option_value_1: "M",
        regular_price_cents: 1200
      }
    )
    assert_equal "Like New · M", used_a.name

    used_b = ProductVariants::Create.call(
      product: product,
      actor: @actor,
      attributes: {
        variant_type: "used",
        status: "draft",
        merchandise_condition_id: second_condition.id,
        merchandise_class_id: @used_klass.id,
        option_value_1: "M",
        regular_price_cents: 1000
      }
    )
    assert_equal "Good · M", used_b.name
  end

  test "name is not independently editable and condition rename refreshes projections" do
    product = Products::Create.call(
      attributes: { name: "Book", status: "active", merchandise_category: @category, list_price_cents: 1000 },
      actor: @actor
    )
    used = ProductVariants::Create.call(
      product: product,
      actor: @actor,
      attributes: {
        variant_type: "used",
        status: "draft",
        merchandise_condition_id: @condition.id,
        merchandise_class_id: @used_klass.id,
        regular_price_cents: 800,
        name: "Custom"
      }
    )
    assert_equal "Like New", used.name

    @condition.update!(name: "Excellent")
    MerchandiseConditions::RefreshVariantNames.call(condition: @condition)
    assert_equal "Excellent", used.reload.name
  end

  test "duplicate unattributed standards are rejected including concurrent insert" do
    product = Products::Create.call(
      attributes: { name: "One Standard", status: "active", merchandise_category: @category, list_price_cents: 1000 },
      actor: @actor
    )
    ProductVariants::Create.call(
      product: product,
      actor: @actor,
      attributes: { variant_type: "standard", status: "draft", regular_price_cents: 1000 }
    )
    error = assert_raises(ProductVariants::Create::Error) do
      ProductVariants::Create.call(
        product: product,
        actor: @actor,
        attributes: { variant_type: "standard", status: "draft", regular_price_cents: 1000 }
      )
    end
    assert_match(/already exists/i, error.message)

    assert_raises(ActiveRecord::RecordNotUnique) do
      ProductVariant.insert!({
        id: SecureRandom.uuid_v7,
        product_id: product.id,
        variant_type: "standard",
        sku: Identifiers::Ean13.complete("221", "333333333"),
        merchandise_condition_id: nil,
        option_value_1_normalized: nil,
        option_value_2_normalized: nil,
        name: "Standard",
        status: "draft",
        lock_version: 0,
        created_at: Time.current,
        updated_at: Time.current
      })
    end
  end
end
