# frozen_string_literal: true

require "ipaddr"
require "net/http"
require "stringio"
require "marcel"

module Bibliographic
  class CoverDownloader
    class Error < CoverPayload::Error; end

    MAX_BYTES = CoverPayload::MAX_BYTES
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 10
    MAX_REDIRECTS = 3
    ALLOWED_MIME = CoverPayload::ALLOWED_MIME
    ALLOWED_HOSTS = %w[images.isbndb.com].freeze

    Result = Struct.new(:bytes, :content_type, :filename, :source_url, keyword_init: true) do
      alias_method :source_url, :source_url
    end

    def self.call(url:, allowed_urls: [], resolver: nil, transport: nil)
      new(url: url, allowed_urls: allowed_urls, resolver: resolver, transport: transport).call
    end

    def initialize(url:, allowed_urls: [], resolver: nil, transport: nil)
      @url = url.to_s.strip
      @allowed_urls = Array(allowed_urls).map(&:to_s)
      @resolver = resolver || method(:resolve_ips)
      @transport = transport || method(:http_get)
    end

    def call
      raise Error, "cover URL is required" if @url.blank?

      uri = parse_https!(@url)
      assert_allowed_destination!(uri)
      status, headers, body = follow(uri, redirects: 0)
      raise Error, "cover download failed (#{status})" unless status.to_i.between?(200, 299)

      declared = (headers["content-type"] || headers["Content-Type"]).to_s.split(";").first.to_s.strip.downcase
      payload = CoverPayload.from_bytes(body, filename: filename_hint(uri), declared_type: declared)

      Result.new(
        bytes: payload.bytes,
        content_type: payload.content_type,
        filename: payload.filename.presence || filename_for(uri, payload.content_type),
        source_url: @url
      )
    rescue Error
      raise
    rescue CoverPayload::Error => e
      raise Error, e.message
    rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, Timeout::Error, Errno::ETIMEDOUT, Net::ReadTimeout, Net::OpenTimeout, Net::WriteTimeout
      raise Error, "cover download timed out"
    rescue StandardError
      raise Error, "cover download failed"
    end

    private

    def follow(uri, redirects:)
      assert_allowed_destination!(uri)
      status, headers, body = @transport.call(uri)
      code = status.to_i
      if [ 301, 302, 303, 307, 308 ].include?(code)
        raise Error, "too many redirects" if redirects >= MAX_REDIRECTS

        location = headers["location"] || headers["Location"]
        raise Error, "redirect without a location" if location.blank?

        return follow(parse_https!(URI.join(uri.to_s, location).to_s), redirects: redirects + 1)
      end
      length = headers["content-length"] || headers["Content-Length"]
      raise Error, "cover is too large" if length.present? && length.to_i > MAX_BYTES
      raise Error, "cover is too large" if body.bytesize > MAX_BYTES

      [ status, headers, body ]
    end

    def parse_https!(value)
      uri = URI.parse(value)
      raise Error, "cover URL must be HTTPS" unless uri.is_a?(URI::HTTPS) && uri.host.present?

      uri
    rescue URI::InvalidURIError
      raise Error, "cover URL is invalid"
    end

    def assert_allowed_destination!(uri)
      unless allowed_url?(uri) || ALLOWED_HOSTS.include?(uri.host.to_s.downcase)
        raise Error, "cover host is not allowed"
      end

      ips = Array(@resolver.call(uri.host))
      raise Error, "cover host could not be resolved" if ips.empty?
      raise Error, "cover destination is not a public address" if ips.any? { |ip| forbidden_ip?(ip) }
    end

    def allowed_url?(uri)
      @allowed_urls.any? { |allowed| allowed.present? && normalize_url(allowed) == normalize_url(uri.to_s) }
    end

    def normalize_url(value)
      value.to_s.strip
    end

    def resolve_ips(host)
      Addrinfo.getaddrinfo(host, 443, nil, :STREAM).map { |addr| IPAddr.new(addr.ip_address) }
    rescue SocketError, IPAddr::InvalidAddressError
      []
    end

    def forbidden_ip?(ip)
      addr = ip.is_a?(IPAddr) ? ip : IPAddr.new(ip.to_s)
      addr = addr.native
      addr.loopback? || addr.private? || addr.link_local? ||
        IPAddr.new("0.0.0.0/8").include?(addr) ||
        IPAddr.new("100.64.0.0/10").include?(addr) ||
        IPAddr.new("224.0.0.0/4").include?(addr) ||
        IPAddr.new("255.255.255.255").include?(addr) ||
        IPAddr.new("::/128").include?(addr) ||
        IPAddr.new("fc00::/7").include?(addr) ||
        IPAddr.new("fe80::/10").include?(addr) ||
        IPAddr.new("ff00::/8").include?(addr)
    rescue IPAddr::InvalidAddressError
      true
    end

    EXTENSIONS = {
      "image/jpeg" => "jpg",
      "image/png" => "png",
      "image/gif" => "gif",
      "image/webp" => "webp"
    }.freeze

    def http_get(uri)
      ips = Array(@resolver.call(uri.host))
      raise Error, "cover destination is not a public address" if ips.any? { |ip| forbidden_ip?(ip) }

      http = Net::HTTP.new(uri.host, uri.port)
      http.ipaddr = ips.first.to_s if http.respond_to?(:ipaddr=)
      http.use_ssl = true
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT
      http.write_timeout = OPEN_TIMEOUT if http.respond_to?(:write_timeout=)
      response = http.request(Net::HTTP::Get.new(uri))
      body = response.body.to_s
      raise Error, "cover is too large" if body.bytesize > MAX_BYTES

      headers = {}
      response.each_header { |key, value| headers[key] = value }
      [ response.code, headers, body ]
    rescue Error
      raise
    rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error
      raise Error, "cover download timed out"
    rescue StandardError
      raise Error, "cover download failed"
    end

    def filename_hint(uri)
      File.basename(uri.path.presence || "cover")
    end

    def filename_for(uri, mime)
      base = filename_hint(uri)
      return base if File.extname(base).present?

      "cover.#{EXTENSIONS.fetch(mime, 'bin')}"
    end
  end
end
