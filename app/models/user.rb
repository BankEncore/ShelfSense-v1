# frozen_string_literal: true

class User < ApplicationRecord
  ACTOR_TYPES = %w[human system integration scheduled_job].freeze
  SYSTEM_USERNAME = "system"

  has_secure_password validations: false

  belongs_to :deactivated_by, class_name: "User", optional: true
  has_many :role_assignments, dependent: :restrict_with_exception
  has_many :assigned_role_assignments, class_name: "RoleAssignment", foreign_key: :assigned_by_id, inverse_of: :assigned_by, dependent: :restrict_with_exception
  has_many :user_sessions, dependent: :restrict_with_exception

  before_validation :normalize_identity

  validates :username, :display_name, :actor_type, presence: true
  validates :actor_type, inclusion: { in: ACTOR_TYPES }
  validates :username, uniqueness: { case_sensitive: false }
  validates :email, uniqueness: { case_sensitive: false, allow_nil: true }
  validates :password, length: { minimum: 12 }, allow_nil: true
  validate :password_required_for_interactive_humans
  validate :system_actor_constraints

  scope :active, -> { where(active: true) }
  scope :human, -> { where(actor_type: "human") }

  def system_actor?
    actor_type == "system"
  end

  def interactive?
    actor_type == "human"
  end

  def authenticatable?
    interactive? && active? && locked_at.nil? && password_digest.present?
  end

  private

  def normalize_identity
    self.username = username.to_s.strip
    self.email = email.to_s.strip.presence
    self.display_name = display_name.to_s.strip
  end

  def password_required_for_interactive_humans
    return unless interactive?
    return if password_digest.present? || password.present?

    errors.add(:password, "can't be blank")
  end

  def system_actor_constraints
    return unless system_actor?

    errors.add(:username, "must be reserved system username") unless username == SYSTEM_USERNAME
    errors.add(:base, "system actor cannot be deactivated") if !active? || deactivated_at.present?
  end
end
