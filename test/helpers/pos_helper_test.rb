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
end
