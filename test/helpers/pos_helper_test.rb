# frozen_string_literal: true

require "test_helper"

class PosHelperTest < ActionView::TestCase
  test "print line description uses the completed snapshot only" do
    line = PosTransactionLine.new(merchandise_snapshot: { "description" => "Snapshot Book", "sku" => "OLD" })
    assert_equal "Snapshot Book", pos_print_line_description(line)
  end

  test "print line description does not fall back to live product metadata" do
    product = Product.new(name: "Live Product Name")
    variant = ProductVariant.new(sku: "LIVE-SKU", product: product)
    line = PosTransactionLine.new(merchandise_snapshot: {}, product_variant: variant)

    assert_equal "Description unavailable", pos_print_line_description(line)
    refute_includes pos_print_line_description(line), "Live Product Name"
  end

  test "print line description shows unit identity from the snapshot only" do
    product = Product.new(name: "Live Product Name")
    variant = ProductVariant.new(sku: "LIVE-SKU", product: product)
    line = PosTransactionLine.new(
      product_variant: variant,
      merchandise_snapshot: {
        "description" => "Snapshot Used Book",
        "sku" => "OLD-SKU",
        "unit_identifier" => "2200000000001",
        "condition_code" => "like_new"
      }
    )

    assert_equal "Snapshot Used Book  like_new  2200000000001", pos_print_line_description(line)
    refute_includes pos_print_line_description(line), "Live Product Name"
  end

  test "history line description uses the completed snapshot only" do
    line = PosTransactionLine.new(merchandise_snapshot: { "description" => "Snapshot Book", "sku" => "OLD" })
    assert_equal "Snapshot Book  OLD", pos_history_line_description(line)
  end

  test "history line description does not fall back to live product metadata" do
    product = Product.new(name: "Live Product Name")
    variant = ProductVariant.new(sku: "LIVE-SKU", product: product)
    line = PosTransactionLine.new(merchandise_snapshot: {}, product_variant: variant)

    assert_equal "Description not captured", pos_history_line_description(line)
    refute_includes pos_history_line_description(line), "Live Product Name"
  end

  test "history line description shows unit identity from the snapshot only" do
    product = Product.new(name: "Live Product Name")
    variant = ProductVariant.new(sku: "LIVE-SKU", product: product)
    line = PosTransactionLine.new(
      product_variant: variant,
      merchandise_snapshot: {
        "description" => "Snapshot Used Book",
        "sku" => "OLD-SKU",
        "unit_identifier" => "2200000000001",
        "condition_code" => "like_new"
      }
    )

    assert_equal "Snapshot Used Book  like_new  2200000000001", pos_history_line_description(line)
    refute_includes pos_history_line_description(line), "Live Product Name"
  end
end
