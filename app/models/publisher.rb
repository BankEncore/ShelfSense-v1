# frozen_string_literal: true

class Publisher < ApplicationRecord
  has_many :products, dependent: :restrict_with_exception

  before_validation :normalize_name

  validates :name, :name_normalized, presence: true
  validates :name_normalized, uniqueness: true

  def self.find_or_create_normalized!(raw_name)
    name = raw_name.to_s.strip
    raise ArgumentError, "publisher name is blank" if name.blank?

    normalized = Bibliographic::NameNormalizer.call(name)
    raise ArgumentError, "publisher name is blank" if normalized.blank?

    existing = find_by(name_normalized: normalized)
    return existing if existing

    create!(name: name, name_normalized: normalized)
  rescue ActiveRecord::RecordNotUnique
    find_by!(name_normalized: normalized)
  end

  def admin_label
    name
  end

  private

  def normalize_name
    self.name = name.to_s.strip.presence
    self.name_normalized = Bibliographic::NameNormalizer.call(name)
  end
end
