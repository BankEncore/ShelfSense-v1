# frozen_string_literal: true

module Pos
  # Typed workspace-overlay failure for Turbo dialog recovery.
  # Maps domain exception classes at the response boundary — never English copy.
  class OverlayFailure < StandardError
    KINDS = %i[
      authorization_failed
      authorization_prohibited
      parent_validation_failed
      stale_transaction
      transport_uncertain
    ].freeze

    attr_reader :kind, :field

    def initialize(kind:, message:, field: nil)
      @kind = kind.to_sym
      raise ArgumentError, "unknown overlay failure kind: #{@kind}" unless KINDS.include?(@kind)

      @field = field&.to_sym
      super(message)
    end

    def self.from_approver_error(error)
      case error
      when Pos::ApproverAuthenticationFailed
        new(
          kind: :authorization_failed,
          field: :approver_password,
          message: "Manager credentials were not accepted."
        )
      when Pos::SelfApprovalProhibited
        new(
          kind: :authorization_prohibited,
          field: :approver_username,
          message: "You cannot approve your own action."
        )
      when Pos::ApproverNotAuthorized
        new(
          kind: :authorization_prohibited,
          field: :approver_username,
          message: "This manager cannot authorize that action."
        )
      else
        nil
      end
    end

    def self.parent_validation(message)
      new(kind: :parent_validation_failed, message: message.to_s)
    end

    def self.stale(message = "This sale was changed. Reload and try again.")
      new(kind: :stale_transaction, message: message)
    end

    def authorization?
      kind == :authorization_failed || kind == :authorization_prohibited
    end
  end
end
