# frozen_string_literal: true

module Pos
  class AuthenticateApprover
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(username:, password:, store:, action_type:, performer:, permission_key: nil)
      @username = username.to_s.strip
      @password = password
      @store = store
      @action_type = action_type
      @performer = performer
      @permission_key = permission_key.presence || "pos.#{action_type}.approve"
    end

    def call
      if @username.blank? || @password.blank?
        raise Pos::ApproverAuthenticationFailed, "approver credentials are required"
      end

      user = User.find_by("lower(username) = ?", @username.downcase)
      unless user&.authenticatable?
        raise Pos::ApproverAuthenticationFailed, "approver credentials are invalid"
      end
      unless user.authenticate(@password)
        raise Pos::ApproverAuthenticationFailed, "approver credentials are invalid"
      end
      raise Pos::SelfApprovalProhibited, "approver cannot be the performer" if user.id == @performer.id
      raise Pos::ApproverNotAuthorized, "approver cannot be the system actor" if user.system_actor?

      unless Authorization::PermissionEvaluator.allowed?(
        user: user,
        permission_key: @permission_key,
        store: @store
      )
        raise Pos::ApproverNotAuthorized, "approver is not authorized at this store"
      end

      user
    end
  end
end
