# frozen_string_literal: true

module Pos
  # Raised when the performer attempts to approve their own controlled action.
  class SelfApprovalProhibited < Denied; end
end
