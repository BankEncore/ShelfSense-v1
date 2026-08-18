# frozen_string_literal: true

module Pos
  class AuthenticateApprover
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(username:, password:, store:, action_type:, performer:)
      @username = username.to_s.strip
      @password = password
      @store = store
      @action_type = action_type
      @performer = performer
    end

    def call
      raise Pos::Denied, "approver credentials are required" if @username.blank? || @password.blank?

      user = User.find_by("lower(username) = ?", @username.downcase)
      raise Pos::Denied, "approver credentials are invalid" unless user&.authenticatable?
      raise Pos::Denied, "approver credentials are invalid" unless user.authenticate(@password)
      raise Pos::Denied, "approver cannot be the performer" if user.id == @performer.id
      raise Pos::Denied, "approver cannot be the system actor" if user.system_actor?

      unless Authorization::PermissionEvaluator.allowed?(
        user: user,
        permission_key: "pos.#{@action_type}.approve",
        store: @store
      )
        raise Pos::Denied, "approver is not authorized at this store"
      end

      user
    end
  end
end
