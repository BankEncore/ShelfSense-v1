# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"
require "uri"

module Bibliographic
  class HttpClient
    class Error < StandardError; end
    class TimeoutError < Error; end
    class Unavailable < Error; end

    Result = Struct.new(:status, :body, keyword_init: true)

    def initialize(base_url: "https://api2.isbndb.com", api_key: ENV["ISBNDB_API_KEY"], timeout: 5)
      @base_url = base_url
      @api_key = api_key.to_s.presence
      @timeout = timeout
    end

    def configured?
      @api_key.present?
    end

    def get(path)
      raise Unavailable, "ISBNdb is not configured" unless configured?

      uri = URI.parse("#{@base_url.to_s.chomp('/')}/#{path.delete_prefix('/')}")
      http = build_http(uri)
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = @api_key
      request["Accept"] = "application/json"

      response = http.request(request)
      Result.new(status: response.code.to_i, body: parse_body(response.body))
    rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error
      raise TimeoutError, "ISBNdb request timed out"
    rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, OpenSSL::SSL::SSLError => e
      raise Unavailable, e.message
    end

    private

    def build_http(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = @timeout
      http.read_timeout = @timeout
      http
    end

    def parse_body(raw)
      return {} if raw.blank?

      JSON.parse(raw)
    rescue JSON::ParserError
      {}
    end
  end
end
