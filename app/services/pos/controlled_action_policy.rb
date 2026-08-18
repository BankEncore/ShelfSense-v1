# frozen_string_literal: true

module Pos
  class ControlledActionPolicy
    VERSION = PosControlledAction::POLICY_VERSION
    RESULTS = %i[direct approval_required prohibited].freeze

    def self.result(user:, store:, action_type:)
      new(user: user, store: store, action_type: action_type).result
    end

    def initialize(user:, store:, action_type:)
      @user = user
      @store = store
      @action_type = action_type
    end

    def result
      return :prohibited unless allowed?("perform")
      return :direct if allowed?("approve")

      :approval_required
    end

    private

    def allowed?(kind)
      Authorization::PermissionEvaluator.allowed?(
        user: @user,
        permission_key: "pos.#{@action_type}.#{kind}",
        store: @store
      )
    end
  end
end
