# frozen_string_literal: true

module UuidV7PrimaryKey
  extend ActiveSupport::Concern

  included do
    before_validation :assign_uuid_v7, on: :create
  end

  private

  def assign_uuid_v7
    return unless uuid_primary_key?

    self.id ||= SecureRandom.uuid_v7
  end

  def uuid_primary_key?
    self.class.type_for_attribute("id").type == :uuid
  end
end
