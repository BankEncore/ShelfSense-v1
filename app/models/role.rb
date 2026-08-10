# frozen_string_literal: true

class Role < ApplicationRecord
  ASSIGNMENT_SCOPES = %w[global store either].freeze

  belongs_to :deactivated_by, class_name: "User", optional: true
  has_many :role_permissions, dependent: :restrict_with_exception
  has_many :permissions, through: :role_permissions
  has_many :role_assignments, dependent: :restrict_with_exception

  validates :key, :name, :assignment_scope, presence: true
  validates :key, uniqueness: true
  validates :name, uniqueness: { case_sensitive: false }
  validates :assignment_scope, inclusion: { in: ASSIGNMENT_SCOPES }

  scope :active, -> { where(active: true) }

  def allows_global_assignment?
    assignment_scope.in?(%w[global either])
  end

  def allows_store_assignment?
    assignment_scope.in?(%w[store either])
  end
end
