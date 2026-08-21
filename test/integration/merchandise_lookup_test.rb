# frozen_string_literal: true

require "test_helper"

class MerchandiseLookupTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @actor = @bootstrap[:administrator]
    sign_in_as("admin")
  end

  test "product industry identifier resolves to the owning product" do
    product = Products::Create.call(
      attributes: { name: "Industry Lookup", status: "draft" },
      actor: @actor,
      industry_identifier: external_isbn13
    )

    post admin_merchandise_lookups_path, params: { lookup: { raw: "978-1-234-56789-7" } }

    assert_response :success
    assert_match(/Status: product/, response.body)
    assert_match(/#{product.primary_identifier} — Industry Lookup/, response.body)
  end

  test "a shared lookup code lists every candidate instead of picking one" do
    first = Products::Create.call(
      attributes: { name: "Alpha", status: "draft" },
      actor: @actor,
      lookup_code: "shared"
    )
    second = Products::Create.call(
      attributes: { name: "Beta", status: "draft" },
      actor: @actor,
      lookup_code: "shared"
    )

    post admin_merchandise_lookups_path, params: { lookup: { raw: "shared" } }

    assert_response :success
    assert_match(/Status: multiple_products/, response.body)
    assert_match(/never picks the first match/, response.body)
    assert_match(/#{first.primary_identifier}/, response.body)
    assert_match(/#{second.primary_identifier}/, response.body)
  end

  test "a retired identifier reports retirement and does not fall through to a lookup code" do
    retired = Products::Create.call(
      attributes: { name: "Retired", status: "draft" },
      actor: @actor
    )
    decoy = Products::Create.call(
      attributes: { name: "Decoy", status: "draft" },
      actor: @actor
    )
    decoy.update!(lookup_code: retired.primary_identifier)
    Identifiers::Registry.retire!(value: retired.primary_identifier)

    post admin_merchandise_lookups_path, params: { lookup: { raw: retired.primary_identifier } }

    assert_response :success
    assert_match(/Status: retired/, response.body)
    assert_no_match(/Decoy/, response.body)
  end

  test "an unmatched lookup code reports not_found" do
    post admin_merchandise_lookups_path, params: { lookup: { raw: "no-such-code" } }

    assert_response :success
    assert_match(/Status: not_found/, response.body)
  end

  private

  def sign_in_as(username)
    delete session_path
    follow_redirect! while response.redirect?
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
    follow_redirect! if response.redirect?
  end
end
