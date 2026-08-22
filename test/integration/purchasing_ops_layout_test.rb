# frozen_string_literal: true

require "test_helper"

class PurchasingOpsLayoutTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    sign_in
  end

  test "ops loads its dedicated Turbo entry point while admin remains server rendered" do
    get ops_location_path

    assert_response :success
    assert_select "html:not([data-turbo='false'])"
    assert_select "script[type='module']", text: /import \"purchasing_ops\"/
    assert_select "[data-controller~='ops-shortcuts']"

    get root_path

    assert_response :success
    assert_select "html[data-turbo='false']"
    assert_select "script[type='module']", text: /import \"application\"/
    assert_select "script[type='module']", text: /purchasing_ops/, count: 0
  end

  private

  def sign_in
    post session_path, params: { session: { username: @actor.username, password: "correct-horse-battery" } }
  end
end
