# frozen_string_literal: true

module Authorization
  class PermissionEvaluator
    def self.permissions_for(user:, store:)
      new(user: user, store: store).permission_keys
    end

    def self.allowed?(user:, permission_key:, store: nil)
      new(user: user, store: store).allowed?(permission_key)
    end

    def initialize(user:, store:)
      @user = user
      @store = store
    end

    def permission_keys
      return Set.new if @user.nil? || !@user.active?

      keys = Set.new
      effective_assignments.find_each do |assignment|
        assignment.role.permissions.active.find_each do |permission|
          next unless permission_applies?(permission, assignment)

          keys << permission.key
        end
      end
      keys
    end

    def allowed?(permission_key)
      permission_keys.include?(permission_key)
    end

    private

    def effective_assignments
      scope = RoleAssignment.effective.where(user_id: @user.id).joins(:role).merge(Role.active).includes(role: :permissions)
      if @store
        scope.where("store_id IS NULL OR store_id = ?", @store.id)
      else
        scope.global
      end
    end

    def permission_applies?(permission, assignment)
      case permission.scope_type
      when "global"
        assignment.global?
      when "store"
        @store.present? && (assignment.global? || assignment.store_id == @store.id)
      when "either"
        assignment.global? || (@store.present? && assignment.store_id == @store.id)
      else
        false
      end
    end
  end
end
