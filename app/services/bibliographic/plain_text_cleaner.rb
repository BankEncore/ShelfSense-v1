# frozen_string_literal: true

require "cgi"

module Bibliographic
  module PlainTextCleaner
    module_function

    MAX_LENGTH = 20_000

    def call(raw)
      text = raw.to_s
      return if text.blank?

      text = text.gsub(%r{<script\b[^>]*>.*?</script>}mi, " ")
      text = text.gsub(%r{<style\b[^>]*>.*?</style>}mi, " ")
      text = text.gsub(%r{<br\s*/?>}i, "\n")
      text = text.gsub(%r{</p>}i, "\n")
      text = ActionView::Base.full_sanitizer.sanitize(text)
      text = CGI.unescapeHTML(text.to_s)
      text = text.gsub(/\r\n?/, "\n")
      text = text.gsub(/[ \t]+\n/, "\n")
      text = text.gsub(/\n{3,}/, "\n\n")
      text = text.gsub(/[ \t]+/, " ")
      text = text.strip
      text = text.truncate(MAX_LENGTH, omission: "")
      text.presence
    end
  end
end
