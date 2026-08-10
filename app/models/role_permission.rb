# frozen_string_literal: true

class RolePermission < ApplicationRecord
  belongs_to :role
  belongs_to :permission
  belongs_to :granted_by, class_name: "User"

  validates :role_id, uniqueness: { scope: :permission_id }

  after_create :bump_role_lock_version
  after_destroy :bump_role_lock_version

  private

  def bump_role_lock_version
    role.update!(updated_at: Time.current)
  end
end
