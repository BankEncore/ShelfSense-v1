# frozen_string_literal: true

module Pos
  # Raised when an authenticated approver lacks store permission (or is the system actor).
  class ApproverNotAuthorized < Denied; end
end
