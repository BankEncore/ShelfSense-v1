# frozen_string_literal: true

class Permission < ApplicationRecord
  SCOPE_TYPES = %w[global store either].freeze

  has_many :role_permissions, dependent: :restrict_with_exception
  has_many :roles, through: :role_permissions

  validates :key, :group_key, :name, :scope_type, presence: true
  validates :key, uniqueness: true
  validates :scope_type, inclusion: { in: SCOPE_TYPES }

  scope :active, -> { where(active: true) }
end
