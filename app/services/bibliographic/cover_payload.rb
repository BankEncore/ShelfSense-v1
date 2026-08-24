# frozen_string_literal: true

require "marcel"
require "stringio"

module Bibliographic
  class CoverPayload
    class Error < StandardError; end

    MAX_BYTES = 5 * 1024 * 1024
    ALLOWED_MIME = %w[image/jpeg image/png image/gif image/webp].freeze
    EXTENSIONS = {
      "image/jpeg" => "jpg",
      "image/png" => "png",
      "image/gif" => "gif",
      "image/webp" => "webp"
    }.freeze

    Result = Struct.new(:bytes, :content_type, :filename, keyword_init: true)

    def self.from_bytes(bytes, filename: nil, declared_type: nil)
      new(bytes: bytes, filename: filename, declared_type: declared_type).call
    end

    def self.from_upload(upload)
      io, filename, declared = extract_upload(upload)
      bytes = read_limited(io)
      from_bytes(bytes, filename: filename, declared_type: declared)
    end

    def self.extract_upload(upload)
      if upload.is_a?(Hash)
        data = upload.stringify_keys
        [ data["io"], data["filename"].to_s, data["content_type"].to_s ]
      elsif upload.respond_to?(:tempfile)
        [ upload.tempfile, upload.original_filename.to_s, upload.content_type.to_s ]
      else
        [ upload, upload.try(:original_filename).to_s.presence || "cover", upload.try(:content_type) ]
      end
    end

    def self.read_limited(io)
      io.rewind if io.respond_to?(:rewind)
      if io.respond_to?(:size) && io.size && io.size > MAX_BYTES
        raise Error, "cover is too large"
      end

      bytes = io.read
      io.rewind if io.respond_to?(:rewind)
      raise Error, "cover is too large" if bytes.to_s.bytesize > MAX_BYTES

      bytes.to_s
    end

    def initialize(bytes:, filename: nil, declared_type: nil)
      @bytes = bytes.to_s
      @filename = filename.to_s
      @declared_type = declared_type.to_s.split(";").first.to_s.strip.downcase
    end

    def call
      raise Error, "cover is too large" if @bytes.bytesize > MAX_BYTES
      raise Error, "cover is not an accepted image" if @bytes.blank?

      mime = Marcel::MimeType.for(StringIO.new(@bytes))
      raise Error, "cover is not an accepted image" unless ALLOWED_MIME.include?(mime)
      if @declared_type.start_with?("image/") && @declared_type != mime
        raise Error, "cover is not an accepted image"
      end

      Result.new(
        bytes: @bytes,
        content_type: mime,
        filename: filename_for(mime)
      )
    end

    private

    def filename_for(mime)
      return @filename if @filename.present? && File.extname(@filename).present?

      "cover.#{EXTENSIONS.fetch(mime, 'bin')}"
    end
  end
end
