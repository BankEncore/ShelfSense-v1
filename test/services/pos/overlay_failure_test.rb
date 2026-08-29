# frozen_string_literal: true

require "test_helper"

class PosOverlayFailureTest < ActiveSupport::TestCase
  test "maps authentication failures by class" do
    failure = Pos::OverlayFailure.from_approver_error(
      Pos::ApproverAuthenticationFailed.new("approver credentials are invalid")
    )
    assert_equal :authorization_failed, failure.kind
    assert_equal :approver_password, failure.field
    assert_equal "Manager credentials were not accepted.", failure.message
  end

  test "maps self-approval separately from credential failure" do
    failure = Pos::OverlayFailure.from_approver_error(
      Pos::SelfApprovalProhibited.new("approver cannot be the performer")
    )
    assert_equal :authorization_prohibited, failure.kind
    assert_equal :approver_username, failure.field
    assert_equal "You cannot approve your own action.", failure.message
  end

  test "maps unauthorized approver by class" do
    failure = Pos::OverlayFailure.from_approver_error(
      Pos::ApproverNotAuthorized.new("approver is not authorized at this store")
    )
    assert_equal :authorization_prohibited, failure.kind
    assert_equal :approver_username, failure.field
    assert_equal "This manager cannot authorize that action.", failure.message
  end

  test "ignores unrelated denials" do
    assert_nil Pos::OverlayFailure.from_approver_error(Pos::Denied.new("not authorized to perform this action"))
  end

  test "does not route by English copy of a generic denial" do
    assert_nil Pos::OverlayFailure.from_approver_error(
      Pos::Denied.new("approver credentials are invalid")
    )
  end

  test "rejects unknown kinds" do
    assert_raises(ArgumentError) { Pos::OverlayFailure.new(kind: :nope, message: "x") }
  end
end
