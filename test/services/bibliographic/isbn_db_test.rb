# frozen_string_literal: true

require "test_helper"

class Bibliographic::IsbnDbTest < ActiveSupport::TestCase
  test "maps a book payload onto a candidate and ignores merchant prices and original images" do
    http = FakeIsbnDbHttp.new(
      responses: { "book/#{FIXTURE_ISBN13}" => [ 200, { "book" => isbndb_book_payload } ] }
    )
    candidates = Bibliographic::Providers::IsbnDb.new(http: http).find_by_isbn(FIXTURE_ISBN13)

    assert_equal 1, candidates.length
    candidate = candidates.first
    assert_equal FIXTURE_ISBN13, candidate.isbn13
    assert_equal "The Left Hand of Darkness", candidate.title
    assert_equal "50th Anniversary Edition", candidate.subtitle
    assert_equal [ { "display_name" => "Ursula K. Le Guin", "role" => "author" } ], candidate.contributors
    assert_equal "Ace", candidate.publisher_name
    assert_equal "Paperback", candidate.binding
    assert_equal "en", candidate.language_code
    assert_equal 304, candidate.page_count
    assert_equal Date.new(1969, 1, 1), candidate.release_date
    assert candidate.release_date_approximate
    assert_equal 1699, candidate.list_price_cents
    assert_equal "https://images.isbndb.com/covers/81/25/9780441478125.jpg", candidate.cover_image_url
    assert_not_includes candidate.to_h.values.flatten, "https://images.isbndb.com/original/expires"
    assert_equal "Ace", candidate.product_attributes[:brand_name]
    assert_equal "50th Anniversary", candidate.product_attributes[:product_model]
    assert_nil candidate.product_attributes[:binding]
    assert_nil candidate.product_attributes[:cover_image_url]
  end

  test "year-month-day publication fills release_date; year-only is approximate" do
    http = FakeIsbnDbHttp.new(
      responses: {
        "book/#{FIXTURE_ISBN13}" => [ 200, { "book" => isbndb_book_payload("date_published" => "1969-03-14") } ]
      }
    )
    candidate = Bibliographic::Providers::IsbnDb.new(http: http).find_by_isbn(FIXTURE_ISBN13).first
    assert_equal Date.new(1969, 3, 14), candidate.release_date
    assert_not candidate.release_date_approximate
  end

  test "returns empty on 404" do
    http = FakeIsbnDbHttp.new(responses: { "book/#{FIXTURE_ISBN13}" => [ 404, {} ] })
    assert_empty Bibliographic::Providers::IsbnDb.new(http: http).find_by_isbn(FIXTURE_ISBN13)
  end

  test "raises a typed error on 401, 429, and 5xx" do
    [ 401, 429, 500 ].each do |status|
      http = FakeIsbnDbHttp.new(responses: { "book/#{FIXTURE_ISBN13}" => [ status, {} ] })
      assert_raises(Bibliographic::HttpClient::Unavailable) do
        Bibliographic::Providers::IsbnDb.new(http: http).find_by_isbn(FIXTURE_ISBN13)
      end
    end
  end

  test "missing API key is unavailable rather than a 500" do
    provider = Bibliographic::Providers::IsbnDb.new(http: Bibliographic::HttpClient.new(api_key: nil))
    assert_not provider.configured?
    error = assert_raises(Bibliographic::HttpClient::Unavailable) do
      provider.find_by_isbn(FIXTURE_ISBN13)
    end
    assert_match(/not configured/i, error.message)
  end

  test "title search maps books or data arrays" do
    http = FakeIsbnDbHttp.new(
      responses: {
        "books/" => [ 200, { "books" => [ isbndb_book_payload ] } ]
      }
    )
    candidates = Bibliographic::Providers::IsbnDb.new(http: http).search_title("Left Hand")
    assert_equal 1, candidates.length
    assert_equal FIXTURE_ISBN13, candidates.first.isbn13
  end

  test "omits unparseable MSRP" do
    http = FakeIsbnDbHttp.new(
      responses: { "book/#{FIXTURE_ISBN13}" => [ 200, { "book" => isbndb_book_payload("msrp" => "unknown") } ] }
    )
    candidate = Bibliographic::Providers::IsbnDb.new(http: http).find_by_isbn(FIXTURE_ISBN13).first
    assert_nil candidate.list_price_cents
  end

  test "maps known language names and codes besides English" do
    {
      "French" => "fr",
      "fra" => "fr",
      "Spanish" => "es",
      "deu" => "de",
      "German" => "de"
    }.each do |raw, expected|
      http = FakeIsbnDbHttp.new(
        responses: { "book/#{FIXTURE_ISBN13}" => [ 200, { "book" => isbndb_book_payload("language" => raw) } ] }
      )
      candidate = Bibliographic::Providers::IsbnDb.new(http: http).find_by_isbn(FIXTURE_ISBN13).first
      assert_equal expected, candidate.language_code, raw
    end
  end

  test "ISBN-less books get a candidate-scoped provider key" do
    http = FakeIsbnDbHttp.new(
      responses: {
        "books/" => [ 200, { "books" => [ isbndb_book_payload("isbn" => nil, "isbn13" => nil) ] } ]
      }
    )
    candidate = Bibliographic::Providers::IsbnDb.new(http: http).search_title("Left Hand").first
    assert_nil candidate.isbn13
    assert_match(/\Aisbndb:candidate:/, candidate.provider_key)
    assert_equal candidate.candidate_id, candidate.provider_key.delete_prefix("isbndb:candidate:")
  end
end
