# frozen_string_literal: true

module Bibliographic
  module CoverUrlMigration
    module_function

    def call
      report = []
      return report unless Product.column_names.include?("cover_image_url")

      Product.where.not(cover_image_url: [ nil, "" ]).find_each do |product|
        url = product.cover_image_url
        begin
          result = CoverDownloader.call(url: url, allowed_urls: [ url ])
          product.cover_image.attach(
            io: StringIO.new(result.bytes),
            filename: result.filename,
            content_type: result.content_type
          )
        rescue CoverDownloader::Error, StandardError => e
          report << { "product_id" => product.id, "url" => url, "error" => e.message }
        end
      end
      report
    end
  end
end
