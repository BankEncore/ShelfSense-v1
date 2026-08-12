# frozen_string_literal: true

require "test_helper"

class BusinessDateTest < ActiveSupport::TestCase
  include Phase2Fixtures

  test "derives store-local calendar date" do
    actor_user
    store = Store.find_by!(code: "main")
    at = Time.utc(2026, 8, 12, 3, 0, 0)
    assert_equal Date.new(2026, 8, 11), BusinessDate.for_store(store, at: at)
  end
end
