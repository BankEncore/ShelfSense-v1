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

  test "basket title uses snapshot description only" do
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

    assert_equal "Snapshot Used Book", pos_basket_line_title(line)
    assert_equal(
      [ { text: "like_new", mono: false }, { text: "2200000000001", mono: true } ],
      pos_basket_line_metadata(line)
    )
    refute_includes pos_basket_line_title(line), "Live Product Name"
  end

  test "basket metadata prefers sku when unit is absent" do
    line = PosTransactionLine.new(
      merchandise_snapshot: { "description" => "Snapshot Book", "sku" => "OLD" }
    )

    assert_equal [ { text: "OLD", mono: true } ], pos_basket_line_metadata(line)
  end

  test "print line description remains one-line after basket helpers" do
    line = PosTransactionLine.new(
      merchandise_snapshot: {
        "description" => "Snapshot Used Book",
        "sku" => "OLD-SKU",
        "unit_identifier" => "2200000000001",
        "condition_code" => "like_new"
      }
    )

    assert_equal "Snapshot Used Book  like_new  2200000000001", pos_print_line_description(line)
    assert_equal "Snapshot Used Book  like_new  2200000000001", pos_line_description(line)
  end

  test "controlled-line flags use Core facts only" do
    line = PosTransactionLine.new(
      direction: "sale",
      reference_unit_price_cents: 1999,
      selling_unit_price_cents: 1500,
      manual_discount_basis_points: 1000,
      tax_class_id: "11111111-1111-1111-1111-111111111111",
      default_tax_class_id: "22222222-2222-2222-2222-222222222222"
    )

    assert pos_line_controlled?(line)
    assert_equal(
      [
        { text: "Override", kind: "override" },
        { text: "Discount", kind: "discount" },
        { text: "Tax Override", kind: "tax" }
      ],
      pos_line_flag_tags(line)
    )
    assert_equal "Override · Discount · Tax Override", pos_line_control_flags(line)
  end

  test "controlled-action provenance names the action type and note" do
    action = PosControlledAction.new(
      action_type: "price_override",
      performed_by_name_snapshot: "John",
      approved_by_name_snapshot: "Pat",
      reason_name_snapshot: "Other",
      reason_note: "customer requested"
    )

    assert_equal "Price override", pos_controlled_action_label(action)
    assert_equal(
      "Price override · Performed by John · Approved by Pat · Other · Note customer requested",
      pos_controlled_action_provenance(action)
    )
  end

  test "direct controlled-action provenance omits approver and blank note" do
    action = PosControlledAction.new(
      action_type: "tax_class_override",
      performed_by_name_snapshot: "John",
      reason_name_snapshot: "Classification correction"
    )

    assert_equal "Tax Class override", pos_controlled_action_label(action)
    assert_equal(
      "Tax Class override · Performed by John · Classification correction",
      pos_controlled_action_provenance(action)
    )
  end

  test "unlinked return price distinction is not a sale override" do
    line = PosTransactionLine.new(
      direction: "return",
      original_transaction_line_id: nil,
      reference_unit_price_cents: 1999,
      selling_unit_price_cents: 1800
    )

    assert pos_unlinked_return_price_adjusted?(line)
    refute pos_line_controlled?(line)
    assert_equal [ { text: "Unlinked return", kind: "return" } ], pos_line_flag_tags(line)
    assert_equal "Unlinked return", pos_line_control_flags(line)
  end
end
