# frozen_string_literal: true

require "test_helper"

class Bibliographic::HttpClientTest < ActiveSupport::TestCase
  test "missing API key is unavailable" do
    client = Bibliographic::HttpClient.new(api_key: nil)
    assert_not client.configured?
    error = assert_raises(Bibliographic::HttpClient::Unavailable) { client.get("book/#{FIXTURE_ISBN13}") }
    assert_match(/not configured/i, error.message)
    assert_no_match(/ISBNDB_API_KEY|sk-/i, error.message)
  end

  test "read timeouts become TimeoutError" do
    client = Bibliographic::HttpClient.new(api_key: "test-key")
    client.define_singleton_method(:build_http) { |_| raise Net::ReadTimeout }

    error = assert_raises(Bibliographic::HttpClient::TimeoutError) { client.get("book/#{FIXTURE_ISBN13}") }
    assert_match(/timed out/i, error.message)
  end
end
