# frozen_string_literal: true

module StoredValue
  class AuthenticateApprover
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(username:, password:, performer:, permission_key:, store: nil)
      @username = username.to_s.strip
      @password = password
      @performer = performer
      @permission_key = permission_key
      @store = store
    end

    def call
      raise Error, "approver credentials are required" if @username.blank? || @password.blank?

      user = User.find_by("lower(username) = ?", @username.downcase)
      raise Error, "approver credentials are invalid" unless user&.authenticatable?
      raise Error, "approver credentials are invalid" unless user.authenticate(@password)
      raise Error, "approver cannot be the performer" if user.id == @performer.id
      raise Error, "approver cannot be the system actor" if user.system_actor?

      unless Authorization::PermissionEvaluator.allowed?(
        user: user,
        permission_key: @permission_key,
        store: @store
      )
        raise Error, "approver is not authorized"
      end

      user
    end
  end
end
