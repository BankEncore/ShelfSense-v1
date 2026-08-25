# frozen_string_literal: true

require "cgi"
require "erb"

module Bibliographic
  module Providers
    class IsbnDb
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
          contributors: map_authors(book),
          publisher_name: book["publisher"].to_s.presence,
          edition: book["edition"].to_s.presence,
          binding: book["binding"].to_s.presence,
          language_code: normalize_language(book["language"]),
          page_count: book["pages"].presence&.to_i&.then { |n| n.positive? ? n : nil },
          series_name: book["series"].to_s.presence || book["series_name"].to_s.presence,
          series_position: parse_series_position(book["series_position"] || book["volume"]),
          release_date: date[:date],
          release_date_approximate: date[:approximate],
          description: Bibliographic::PlainTextCleaner.call(book["synopsis"].presence || book["overview"]),
          cover_image_url: https_image(book["image"]),
          list_price_cents: Bibliographic::Msrp.to_cents(book["msrp"]),
          product_form_code: Bibliographic::ProductFormMapper.code_for(book["binding"]),
          subjects: map_subjects(book["subjects"]),
          provider: "isbndb",
          provider_key: isbn13
        )
      end

      def map_authors(book)
        Array(book["authors"]).filter_map do |entry|
          if entry.is_a?(Hash)
            data = entry.stringify_keys
            name = data["name"].presence || data["display_name"].presence
            next if name.blank?

            { "display_name" => name.to_s.strip, "role" => Bibliographic::ContributorRole.map!(data["role"]) }
          else
            next if entry.blank?

            { "display_name" => entry.to_s.strip, "role" => "author" }
          end
        end
      end

      def map_subjects(raw)
        Array(raw).filter_map do |entry|
          if entry.is_a?(Hash)
            data = entry.stringify_keys
            data["name"].presence || data["code"].presence || data["text"].presence
          else
            entry.to_s.strip.presence
          end
        end
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
        Bibliographic::LanguageCodes.normalize(raw)
      end

      def parse_publication(raw)
        text = raw.to_s.strip
        return {} if text.blank?

        if text.match?(/\A\d{4}-\d{2}-\d{2}\z/)
          { date: Date.iso8601(text), approximate: false }
        elsif text.match?(/\A\d{4}-\d{2}\z/)
          year, month = text.split("-").map(&:to_i)
          { date: Date.new(year, month, 1), approximate: true }
        elsif text.match?(/\A\d{4}\z/)
          { date: Date.new(text.to_i, 1, 1), approximate: true }
        else
          {}
        end
      rescue ArgumentError
        {}
      end

      def parse_series_position(raw)
        text = raw.to_s.strip
        return if text.blank?
        return unless text.match?(/\A-?\d+(?:\.\d+)?\z/)

        BigDecimal(text)
      rescue ArgumentError
        nil
      end

      def https_image(url)
        text = url.to_s.strip
        text if text.match?(%r{\Ahttps://}i)
      end
    end
  end
end
