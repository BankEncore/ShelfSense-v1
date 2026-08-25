# frozen_string_literal: true

module BibliographicFixtures
  module_function

  FIXTURE_ISBN13 = "9780441478125"
  TINY_COVER_PNG = [ "89504e470d0a1a0a0000000d4948445200000001000000010802000000907753de0000000a49444154789c63f80f00000101000518d84e0000000049454e44ae426082" ].pack("H*")

  def bibliographic_candidate(**overrides)
    Bibliographic::Candidate.new(
      **{
        isbn13: FIXTURE_ISBN13,
        title: "The Left Hand of Darkness",
        subtitle: "50th Anniversary Edition",
        contributors: [ { "display_name" => "Ursula K. Le Guin", "role" => "author" } ],
        publisher_name: "Ace",
        edition: "50th Anniversary",
        binding: "Paperback",
        language_code: "en",
        page_count: 304,
        release_date: Date.new(1969, 1, 1),
        release_date_approximate: true,
        description: "A genderless world.",
        cover_image_url: "https://images.isbndb.com/covers/81/25/9780441478125.jpg",
        list_price_cents: 1699,
        provider: "isbndb",
        provider_key: FIXTURE_ISBN13
      }.merge(overrides)
    )
  end

  def isbndb_book_payload(**overrides)
    {
      "title" => "The Left Hand of Darkness",
      "title_long" => "The Left Hand of Darkness: 50th Anniversary Edition",
      "isbn" => "0441478125",
      "isbn13" => FIXTURE_ISBN13,
      "authors" => [ "Ursula K. Le Guin" ],
      "publisher" => "Ace",
      "edition" => "50th Anniversary",
      "binding" => "Paperback",
      "language" => "English",
      "pages" => 304,
      "date_published" => "1969",
      "synopsis" => "A genderless world.",
      "image" => "https://images.isbndb.com/covers/81/25/9780441478125.jpg",
      "image_original" => "https://images.isbndb.com/original/expires",
      "msrp" => "16.99",
      "other_isbns" => [ { "isbn" => "9780441007318" } ],
      "subjects" => [ "Fiction" ],
      "prices" => [ { "merchant" => "Amazon", "price" => "9.99" } ]
    }.merge(overrides.stringify_keys)
  end

  class FakeIsbnDbHttp
    Result = Bibliographic::HttpClient::Result

    attr_reader :requests

    def initialize(responses: {}, configured: true)
      @responses = responses
      @configured = configured
      @requests = []
    end

    def configured?
      @configured
    end

    def get(path)
      raise Bibliographic::HttpClient::Unavailable, "ISBNdb is not configured" unless configured?

      @requests << path
      match = @responses.find { |pattern, _| path == pattern || path.start_with?(pattern.to_s) }
      status, body = match ? match[1] : [ 404, {} ]
      raise status if status.is_a?(Exception) || (status.is_a?(Class) && status < Exception)

      Result.new(status: status, body: body)
    end
  end

  class FakeIsbnDbProvider
    attr_reader :calls

    def initialize(candidates: [], error: nil, configured: true)
      @candidates = Array(candidates)
      @error = error
      @configured = configured
      @calls = []
    end

    def configured?
      @configured
    end

    def find_by_isbn(isbn)
      raise @error if @error

      @calls << [ :isbn, isbn ]
      @candidates.select { |candidate| candidate.isbn13 == isbn }
    end

    def search_title(query)
      raise @error if @error

      @calls << [ :title, query ]
      @candidates
    end
  end

  def stub_bibliographic_provider(provider)
    original = Bibliographic::Search.provider_factory
    Bibliographic::Search.provider_factory = -> { provider }
    yield
  ensure
    Bibliographic::Search.provider_factory = original
  end

  def stub_cover_download(result)
    klass = Bibliographic::CoverDownloader
    singleton = klass.singleton_class
    singleton.alias_method :__original_call, :call
    singleton.define_method(:call) { |**_| result }
    yield
  ensure
    singleton.alias_method :call, :__original_call
    singleton.remove_method :__original_call
  end

  def stub_audit_recorder_failure(message = "audit exploded")
    singleton = Audit::Recorder.singleton_class
    singleton.alias_method :__original_record!, :record!
    singleton.define_method(:record!) { |**_| raise RuntimeError, message }
    yield
  ensure
    singleton.alias_method :record!, :__original_record!
    singleton.remove_method :__original_record!
  end

  def stub_net_http(http)
    singleton = Net::HTTP.singleton_class
    singleton.alias_method :__original_new, :new
    singleton.define_method(:new) { |*| http }
    yield
  ensure
    singleton.alias_method :new, :__original_new
    singleton.remove_method :__original_new
  end
end
