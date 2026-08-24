# frozen_string_literal: true

class Contributor < ApplicationRecord
  has_many :product_contributions, dependent: :restrict_with_exception
  has_many :products, through: :product_contributions

  before_validation :normalize_name

  validates :display_name, :name_normalized, presence: true
  validates :name_normalized, uniqueness: true

  def self.find_or_create_normalized!(raw_name)
    name = raw_name.to_s.strip
    raise ArgumentError, "contributor name is blank" if name.blank?

    normalized = Bibliographic::NameNormalizer.call(name)
    raise ArgumentError, "contributor name is blank" if normalized.blank?

    existing = find_by(name_normalized: normalized)
    return existing if existing

    create!(display_name: name, name_normalized: normalized)
  rescue ActiveRecord::RecordNotUnique
    find_by!(name_normalized: normalized)
  end

  def admin_label
    display_name
  end

  private

  def normalize_name
    self.display_name = display_name.to_s.strip.presence
    self.name_normalized = Bibliographic::NameNormalizer.call(display_name)
  end
end
