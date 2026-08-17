# frozen_string_literal: true

require "test_helper"

class PosGoldenFixturesTest < ActiveSupport::TestCase
  FIXTURES = Rails.root.join("test/fixtures/files/pos")

  test "CompleteTransactionCommand canonical JSON and SHA-256 match committed fixtures" do
    payload = JSON.parse(File.read(FIXTURES.join("complete_transaction_command.json")))
    expected_canonical = File.read(FIXTURES.join("complete_transaction_command.canonical.json"))
    expected_hash = File.read(FIXTURES.join("complete_transaction_command.sha256")).strip

    assert_equal expected_canonical, Idempotency::CanonicalJson.dump(payload)
    assert_equal expected_hash, Idempotency::CanonicalJson.hash(payload)
  end

  test "CompletedPosOperation v1 canonical JSON and SHA-256 match committed fixtures" do
    payload = JSON.parse(File.read(FIXTURES.join("completed_pos_operation_v1/cash_sale.json")))
    expected_canonical = File.read(FIXTURES.join("completed_pos_operation_v1/cash_sale.canonical.json"))
    expected_hash = File.read(FIXTURES.join("completed_pos_operation_v1/cash_sale.sha256")).strip

    assert_equal expected_canonical, Idempotency::CanonicalJson.dump(payload)
    assert_equal expected_hash, Idempotency::CanonicalJson.hash(payload)
    assert_kind_of Integer, payload.fetch("lines").first.fetch("quantity")
    assert payload.fetch("receipt").fetch("sequence").present?
  end

  test "tax golden cases compute half-up independently and include non-applicable rows" do
    catalog = JSON.parse(File.read(FIXTURES.join("tax_cases.json")))
    catalog.fetch("cases").each do |tax_case|
      next if tax_case["blocks_completion"] || tax_case["envelope_fixture"]

      computed = tax_case.fetch("components").sum do |component|
        next 0 unless component.fetch("applies")

        half_up_tax(tax_case.fetch("extended_selling_amount_cents"), component.fetch("rate_percent"))
      end
      assert_equal tax_case.fetch("expected_line_tax_cents"), computed, tax_case.fetch("id")

      tax_case.fetch("components").each do |component|
        if component.fetch("applies")
          assert_equal tax_case.fetch("extended_selling_amount_cents"), component.fetch("taxable_basis_cents"), tax_case.fetch("id")
        else
          assert_equal 0, component.fetch("taxable_basis_cents"), tax_case.fetch("id")
          assert_equal 0, component.fetch("tax_cents"), tax_case.fetch("id")
        end
      end
    end
  end

  test "null applies case is marked as blocking completion" do
    catalog = JSON.parse(File.read(FIXTURES.join("tax_cases.json")))
    blocking = catalog.fetch("cases").find { |tax_case| tax_case["id"] == "07_null_applies_blocks" }

    assert blocking.fetch("blocks_completion")
    assert_nil blocking.fetch("components").first.fetch("applies")
  end

  private

  def half_up_tax(basis_cents, rate_percent)
    (BigDecimal(basis_cents.to_s) * BigDecimal(rate_percent.to_s) / 100).round(0, half: :up).to_i
  end
end
