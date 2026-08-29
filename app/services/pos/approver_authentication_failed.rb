# frozen_string_literal: true

module Pos
  # Raised when approver username/password are missing or do not authenticate.
  class ApproverAuthenticationFailed < Denied; end
end
