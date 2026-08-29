# frozen_string_literal: true

require "test_helper"

class PosOverlayFailureTest < ActiveSupport::TestCase
  test "from_denied maps credential failures" do
    failure = Pos::OverlayFailure.from_denied(Pos::Denied.new("approver credentials are invalid"))
    assert_equal :authorization_failed, failure.kind
    assert_equal :approver_password, failure.field
    assert_match(/Manager credentials were not accepted/, failure.message)
  end

  test "from_denied maps unauthorized approver" do
    failure = Pos::OverlayFailure.from_denied(Pos::Denied.new("approver is not authorized at this store"))
    assert_equal :authorization_prohibited, failure.kind
    assert_equal :approver_username, failure.field
  end

  test "from_denied ignores unrelated denials" do
    assert_nil Pos::OverlayFailure.from_denied(Pos::Denied.new("not authorized to perform this action"))
  end

  test "rejects unknown kinds" do
    assert_raises(ArgumentError) { Pos::OverlayFailure.new(kind: :nope, message: "x") }
  end
end
