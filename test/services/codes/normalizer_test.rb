# frozen_string_literal: true

require "test_helper"

class Codes::NormalizerTest < ActiveSupport::TestCase
  test "normalizes punctuation whitespace and accents" do
    assert_equal "used_books_media", Codes::Normalizer.normalize("Used Books & Media")
    assert_equal "cafe_bakery", Codes::Normalizer.normalize("Café / Bakery")
  end

  test "rejects blank after normalization" do
    assert_raises(ArgumentError) { Codes::Normalizer.normalize!("???") }
  end
end
