# frozen_string_literal: true

require "cgi"
require "erb"

module Bibliographic
  module Providers
    class IsbnDb
      LANGUAGE_MAP = {
        "english" => "eng",
        "eng" => "eng",
        "en" => "eng",
        "french" => "fra",
        "fra" => "fra",
        "fr" => "fra",
        "spanish" => "spa",
        "spa" => "spa",
        "es" => "spa",
        "german" => "deu",
        "deu" => "deu",
        "de" => "deu"
      }.freeze

      def initialize(http: Bibliographic::HttpClient.new)
        @http = http
      end

      def configured?
        @http.configured?
      end

      def find_by_isbn(isbn)
        raise Bibliographic::HttpClient::Unavailable, "ISBNdb is not configured" unless configured?

        result = @http.get("book/#{CGI.escape(isbn)}")
        return [] if result.status == 404
        raise_http!(result) unless result.status == 200

        book = result.body["book"]
        return [] if book.blank?

        [ map_book(book) ]
      end

      def search_title(query)
        raise Bibliographic::HttpClient::Unavailable, "ISBNdb is not configured" unless configured?

        encoded = ERB::Util.url_encode(query.to_s.truncate(150, omission: ""))
        result = @http.get("books/#{encoded}?column=title&pageSize=10")
        return [] if result.status == 404
        raise_http!(result) unless result.status == 200

        Array(result.body["data"] || result.body["books"]).filter_map { |book| map_book(book) }
      end

      private

      def raise_http!(result)
        message =
          case result.status
          when 401 then "ISBNdb rejected the API key"
          when 429 then "ISBNdb rate limit exceeded"
          else "ISBNdb is unavailable"
          end
        raise Bibliographic::HttpClient::Unavailable, message
      end

      def map_book(book)
        book = book.stringify_keys
        isbn13 = normalize_isbn(book["isbn13"].presence || book["isbn"])
        date = parse_publication(book["date_published"])
        Bibliographic::Candidate.new(
          isbn13: isbn13,
          title: book["title"].to_s.presence,
          subtitle: subtitle_from(book),
          contributors: Array(book["authors"]).filter_map { |name|
            next if name.blank?

            { "display_name" => name.to_s.strip, "role" => "author" }
          },
          publisher_name: book["publisher"].to_s.presence,
          edition: book["edition"].to_s.presence,
          binding: book["binding"].to_s.presence,
          language_code: normalize_language(book["language"]),
          page_count: book["pages"].presence&.to_i&.then { |n| n.positive? ? n : nil },
          publication_year: date[:year],
          release_date: date[:date],
          description: book["synopsis"].presence || book["overview"].presence,
          cover_image_url: book["image"].to_s.presence,
          list_price_cents: Bibliographic::Msrp.to_cents(book["msrp"]),
          provider: "isbndb",
          provider_key: isbn13
        )
      end

      def subtitle_from(book)
        long = book["title_long"].to_s
        title = book["title"].to_s
        return if long.blank? || title.blank? || long == title
        return unless long.start_with?(title)

        long.delete_prefix(title).sub(/\A\s*[:\-–]\s*/, "").presence
      end

      def normalize_isbn(raw)
        return if raw.blank?

        Identifiers::Normalizer.normalize(raw, allow_shelfsense_222: false)
      rescue Identifiers::NormalizationError
        nil
      end

      def normalize_language(raw)
        return if raw.blank?

        key = raw.to_s.strip.downcase
        LANGUAGE_MAP[key] || (key.match?(/\A[a-z]{2,3}\z/) ? key : nil)
      end

      def parse_publication(raw)
        text = raw.to_s.strip
        return {} if text.blank?

        if text.match?(/\A\d{4}-\d{2}-\d{2}\z/)
          { date: Date.iso8601(text), year: text[0, 4].to_i }
        elsif text.match?(/\A\d{4}-\d{2}\z/)
          { year: text[0, 4].to_i }
        elsif text.match?(/\A\d{4}\z/)
          { year: text.to_i }
        else
          {}
        end
      rescue ArgumentError
        {}
      end
    end
  end
end
