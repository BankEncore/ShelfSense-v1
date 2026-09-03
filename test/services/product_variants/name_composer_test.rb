# frozen_string_literal: true

require "test_helper"

class ProductVariants::NameComposerTest < ActiveSupport::TestCase
  test "composes all PVA-006 name rows" do
    product = Product.new(variant_option_name_1: nil, variant_option_name_2: nil)
    assert_equal "Standard", ProductVariants::NameComposer.name(
      variant_type: "standard", product: product
    )
    assert_equal "Like New", ProductVariants::NameComposer.name(
      variant_type: "used", condition_name: "Like New", product: product
    )

    attributed = Product.new(variant_option_name_1: "Size", variant_option_name_2: nil)
    assert_equal "M", ProductVariants::NameComposer.name(
      variant_type: "standard", option_value_1: "M", product: attributed
    )
    assert_equal "Like New · M", ProductVariants::NameComposer.name(
      variant_type: "used", condition_name: "Like New", option_value_1: "M", product: attributed
    )

    two = Product.new(variant_option_name_1: "Size", variant_option_name_2: "Color")
    assert_equal "M / Blue", ProductVariants::NameComposer.name(
      variant_type: "standard", option_value_1: "M", option_value_2: "Blue", product: two
    )
    assert_equal "Like New · M / Blue", ProductVariants::NameComposer.name(
      variant_type: "used", condition_name: "Like New", option_value_1: "M", option_value_2: "Blue", product: two
    )
  end

  test "detail omits unattributed Standard and matches attributed names" do
    product = Product.new
    assert_nil ProductVariants::NameComposer.detail(variant_type: "standard", product: product)
    assert_equal "Good", ProductVariants::NameComposer.detail(
      variant_type: "used", condition_name: "Good", product: product
    )

    attributed = Product.new(variant_option_name_1: "Size")
    assert_equal "XL", ProductVariants::NameComposer.detail(
      variant_type: "standard", option_value_1: "XL", product: attributed
    )
  end
end
