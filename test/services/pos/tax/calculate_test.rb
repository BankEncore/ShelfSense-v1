# frozen_string_literal: true

require "test_helper"

class Pos::Tax::CalculateTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    @book = tax_class(code: "physical_book", name: "Physical book")
    @food = tax_class(code: "prepared_food", name: "Prepared food")
  end

  test "golden tax cases match half-up component snapshots including non-applicable rows" do
    catalog = JSON.parse(File.read(Rails.root.join("test/fixtures/files/pos/tax_cases.json")))
    catalog.fetch("cases").each do |tax_case|
      next if tax_case["envelope_fixture"]

      StoreTax.where(store: @store).find_each(&:destroy)
      tax_case.fetch("components").each do |component|
        applies = component["applies"]
        store_tax = StoreTaxes::Create.call(
          store: @store,
          actor: @actor,
          code: component.fetch("store_tax_code"),
          name: component.fetch("store_tax_code").tr("_", " ").capitalize,
          rate_percent: component.fetch("rate_percent"),
          calculation_order: component.fetch("calculation_order"),
          applies_by_tax_class_id: { @book.id => applies.nil? ? "" : applies }
        )
        store_tax.store_tax_rules.find_by!(tax_class: @food).update!(applies: false)
      end

      if tax_case["blocks_completion"]
        assert_raises(Pos::Tax::UnresolvedApplicability) do
          Pos::Tax::Calculate.call(store: @store, tax_class: @book, taxable_basis_cents: tax_case.fetch("extended_selling_amount_cents"))
        end
        next
      end

      result = Pos::Tax::Calculate.call(
        store: @store,
        tax_class: @book,
        taxable_basis_cents: tax_case.fetch("extended_selling_amount_cents")
      )
      assert_equal tax_case.fetch("expected_line_tax_cents"), result.tax_cents, tax_case.fetch("id")
      expected_codes = tax_case.fetch("components").map { |component| component.fetch("store_tax_code") }
      assert_equal expected_codes, result.determinations.map(&:store_tax_code), tax_case.fetch("id")
      result.determinations.each_with_index do |determination, index|
        expected = tax_case.fetch("components")[index]
        assert_equal expected.fetch("applies"), determination.applies, tax_case.fetch("id")
        assert_equal expected.fetch("tax_cents"), determination.tax_cents, tax_case.fetch("id")
        assert_equal expected.fetch("taxable_basis_cents"), determination.taxable_basis_cents, tax_case.fetch("id")
        assert_equal expected.fetch("rate_percent"), determination.rate_percent, tax_case.fetch("id")
      end
    end
  end

  test "creating a store tax ensures unresolved rules for active tax classes" do
    store_tax = StoreTaxes::Create.call(
      store: @store,
      actor: @actor,
      name: "Illinois State",
      rate_percent: "5.000",
      calculation_order: 1
    )

    assert_equal 2, store_tax.store_tax_rules.count
    assert store_tax.store_tax_rules.all? { |rule| rule.applies.nil? }
  end

  test "activating a tax class ensures rules for active store taxes" do
    store_tax = StoreTaxes::Create.call(
      store: @store,
      actor: @actor,
      name: "Illinois State",
      rate_percent: "5.000"
    )
    extra = tax_class(code: "periodicals", name: "Periodicals", active: false)
    StoreTaxes::EnsureRules.for_tax_class(extra)
    assert_not store_tax.store_tax_rules.exists?(tax_class: extra)

    extra.update!(active: true)
    StoreTaxes::EnsureRules.for_tax_class(extra.reload)
    assert store_tax.store_tax_rules.exists?(tax_class: extra)
  end
end
