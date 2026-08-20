# frozen_string_literal: true

require "test_helper"

class PosSearchMerchandiseTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    @tax = tax_class(code: "physical_book", name: "Physical book")
    @exact = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Zebra Search Book")
    @named = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Apple Search Book")
    @retired = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Retired Search Book")
    @retired.update_columns(status: "discontinued")
    @open_used = pos_sellable_variant(
      actor: @actor,
      tax_class: @tax,
      pricing_method: "open_price",
      variant_type: "used",
      name: "Open Used Search"
    )
  end

  test "search always returns a list ranked exact sku then name then sku and caps at 20" do
    21.times do |index|
      pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Limit Search Book #{index.to_s.rjust(2, '0')}")
    end

    limited = Pos::SearchMerchandise.call(store: @store, name: "Limit Search Book")
    assert_equal 20, limited.size
    names = limited.map(&:product_name)
    assert_equal names, names.sort

    ranked = Pos::SearchMerchandise.call(store: @store, sku: @exact.sku, name: "Search Book")
    assert_equal @exact.sku, ranked.first.sku
    assert ranked.size <= 20
  end

  test "unsellable retired and open-price used rows are listed as disabled with a reason" do
    rows = Pos::SearchMerchandise.call(store: @store, name: "Search")
    retired_row = rows.find { |row| row.variant.id == @retired.id }
    used_row = rows.find { |row| row.variant.id == @open_used.id }

    assert retired_row.disabled
    assert_match(/retired/, retired_row.reason)
    assert used_row.disabled
    assert_equal Pos::ResolveMerchandiseForSale::OPEN_PRICE_USED_MESSAGE, used_row.reason
  end
end
