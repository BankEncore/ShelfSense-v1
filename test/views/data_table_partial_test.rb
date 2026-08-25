# frozen_string_literal: true

require "test_helper"

class DataTablePartialTest < ActionView::TestCase
  test "applies cell_class only to td and header_class only to th" do
    render "shared/data_table",
      headers: [
        { text: "Name", cell_class: "cell-primary" },
        { text: "SKU", header_class: "col-sku", cell_class: "cell-identifier" },
        { text: "Price", class: "numeric" }
      ],
      rows: [ [ "Widget", "SKU-1", "$1.00" ] ]

    assert_select "th.cell-primary", count: 0
    assert_select "th.cell-identifier", count: 0
    assert_select "td.cell-primary", text: "Widget"
    assert_select "th.col-sku", text: "SKU"
    assert_select "td.col-sku", count: 0
    assert_select "td.cell-identifier", text: "SKU-1"
    assert_select "th.numeric", text: "Price"
    assert_select "td.numeric", text: "$1.00"
  end
end
