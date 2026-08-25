# frozen_string_literal: true

module SubjectSchemes
  module Catalog
    module_function

    SEEDS = [
      { key: "bisac", name: "BISAC", scheme_version: nil },
      { key: "house", name: "House subjects", scheme_version: nil }
    ].freeze

    def seed!
      SEEDS.each do |attrs|
        scheme = SubjectScheme.find_or_initialize_by(key: attrs[:key])
        next unless scheme.new_record?

        scheme.name = attrs[:name]
        scheme.scheme_version = attrs[:scheme_version]
        scheme.active = true
        scheme.save!
      end
    end
  end
end
