# frozen_string_literal: true

module Authorization
  class StoreAccess
    def self.accessible_stores_for(user)
      return Store.none if user.nil? || !user.active?

      global = RoleAssignment.effective.global.where(user_id: user.id).joins(:role).merge(Role.active).exists?
      return Store.active.order(:name) if global

      store_ids = RoleAssignment.effective.where(user_id: user.id).where.not(store_id: nil).joins(:role).merge(Role.active).select(:store_id)
      Store.active.where(id: store_ids).order(:name)
    end
  end
end
