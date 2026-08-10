# frozen_string_literal: true

class RoleAssignment < ApplicationRecord
  belongs_to :user
  belongs_to :role
  belongs_to :store, optional: true
  belongs_to :assigned_by, class_name: "User"
  belongs_to :revoked_by, class_name: "User", optional: true

  before_validation :set_effective_at, on: :create

  validates :effective_at, presence: true
  validate :assignment_scope_matches_role
  validate :user_must_be_assignable
  validate :expiration_after_effective
  validate :revocation_consistency

  scope :not_revoked, -> { where(revoked_at: nil) }
  scope :effective, lambda {
    now = Time.current
    not_revoked
      .where("effective_at <= ?", now)
      .where("expires_at IS NULL OR expires_at > ?", now)
  }
  scope :global, -> { where(store_id: nil) }
  scope :for_store, ->(store_id) { where(store_id: store_id) }

  def global?
    store_id.nil?
  end

  def revoked?
    revoked_at.present?
  end

  def effective?(at: Time.current)
    !revoked? &&
      effective_at <= at &&
      (expires_at.nil? || expires_at > at) &&
      user.active? &&
      role.active? &&
      (store.nil? || store.active?)
  end

  private

  def set_effective_at
    self.effective_at ||= Time.current
  end

  def assignment_scope_matches_role
    return if role.blank?

    if global? && !role.allows_global_assignment?
      errors.add(:store_id, "must be present for #{role.key} assignments")
    elsif !global? && !role.allows_store_assignment?
      errors.add(:store_id, "must be blank for #{role.key} assignments")
    end
  end

  def user_must_be_assignable
    return if user.blank?
    return unless user.system_actor?

    errors.add(:user_id, "system actor cannot receive role assignments")
  end

  def expiration_after_effective
    return if expires_at.blank? || effective_at.blank?
    return if expires_at > effective_at

    errors.add(:expires_at, "must be later than effective_at")
  end

  def revocation_consistency
    if revoked_at.present? && revoked_by_id.blank?
      errors.add(:revoked_by_id, "is required when revoked")
    end
  end
end
