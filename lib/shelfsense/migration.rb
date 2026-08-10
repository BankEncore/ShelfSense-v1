# frozen_string_literal: true

module Shelfsense
  module Migration
    # UUID primary keys without a database default. Rails assigns UUIDv7 in models.
    def create_uuid_table(name, **options, &block)
      create_table(name, id: :uuid, default: nil, **options, &block)
    end
  end
end
