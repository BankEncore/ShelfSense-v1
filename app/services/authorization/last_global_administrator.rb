# frozen_string_literal: true

module Authorization
  class LastGlobalAdministrator
    SYSTEM_ADMIN_KEY = "system_administrator"

    class WouldRemoveLastAdministrator < StandardError; end

    def self.ensure_remaining!
      new.ensure_remaining!
    end

    def ensure_remaining!
      RoleAssignment.transaction do
        lock_global_system_admin_assignments!
        raise WouldRemoveLastAdministrator, "ShelfSense must retain at least one active global system administrator" if count_effective_global_admins < 1
      end
    end

    def with_lock
      RoleAssignment.transaction do
        lock_global_system_admin_assignments!
        yield
        ensure_remaining_without_new_transaction!
      end
    end

    private

    def lock_global_system_admin_assignments!
      role = Role.find_by!(key: SYSTEM_ADMIN_KEY)
      RoleAssignment.global.where(role_id: role.id).lock.to_a
    end

    def ensure_remaining_without_new_transaction!
      raise WouldRemoveLastAdministrator, "ShelfSense must retain at least one active global system administrator" if count_effective_global_admins < 1
    end

    def count_effective_global_admins
      role = Role.find_by!(key: SYSTEM_ADMIN_KEY)
      RoleAssignment.effective.global.where(role_id: role.id).joins(:user).merge(User.active.human).count
    end
  end
end
