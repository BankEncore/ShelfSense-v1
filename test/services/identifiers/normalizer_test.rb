# frozen_string_literal: true

require "test_helper"

class Identifiers::NormalizerTest < ActiveSupport::TestCase
  test "strips spaces and hyphens" do
    value = Identifiers::Ean13.complete("978", "123456789")
    formatted = "#{value[0, 3]}-#{value[3, 1]}-#{value[4, 6]}-#{value[10, 2]}-#{value[12]}"
    assert_equal value, Identifiers::Normalizer.normalize(" #{formatted} ")
  end

  test "converts ISBN-10 to ISBN-13" do
    assert_equal "9780306406157", Identifiers::Normalizer.normalize("0-306-40615-2")
    assert_equal "9780306406157", Identifiers::Normalizer.normalize("0306406152")
  end

  test "converts UPC-A to GTIN-13" do
    ean13 = Identifiers::Ean13.complete("012", "345678901")
    upc_a = ean13[1, 12]
    assert_equal 12, upc_a.length
    assert_equal ean13, Identifiers::Normalizer.normalize(upc_a)
  end

  test "rejects invalid check digit" do
    body = "978123456789"
    bad = "#{body}#{(Identifiers::Ean13.check_digit(body) + 1) % 10}"
    error = assert_raises(Identifiers::NormalizationError) do
      Identifiers::Normalizer.normalize(bad)
    end
    assert_match(/invalid check digit/i, error.message)
  end

  test "rejects entered 222 namespace unless allowed" do
    value = Identifiers::Ean13.complete("222", "000000001")
    error = assert_raises(Identifiers::NormalizationError) do
      Identifiers::Normalizer.normalize(value, allow_shelfsense_222: false)
    end
    assert_match(/reserved 222/i, error.message)

    assert_equal value, Identifiers::Normalizer.normalize(value, allow_shelfsense_222: true)
  end
end
