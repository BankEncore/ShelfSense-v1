# frozen_string_literal: true

require "test_helper"

class AdminBibliographicReviewCompositionTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    ProductForms::Catalog.seed!
    @product = Products::Create.call(
      attributes: { name: "Existing title", status: "draft" },
      actor: @bootstrap[:administrator]
    )
    @candidate = bibliographic_candidate
    Bibliographic::LookupCache.store("isbn:#{@candidate.isbn13}", [ @candidate ], ttl: 1.hour)
  end

  test "review groups current proposed and selected fields by family" do
    sign_in_as("admin")
    get bibliographic_review_admin_product_path(@product, candidate_id: @candidate.candidate_id)
    assert_response :success

    assert_select ".page-header__eyebrow", text: "Product"
    assert_select ".page-header__title", text: "Review bibliographic data"
    assert_select "form.bibliographic-review.surface"
    %w[Identity Identifiers Publication Cover Pricing].each do |title|
      assert_select ".bibliographic-review h2", text: title
    end
    assert_select "#review-name"
    assert_select "#review-industry_identifier"
    assert_select "#review-list_price_cents"
    assert_select "#current-name", text: "Existing title"
    assert_select "input[name='proposed[name]']"
    assert_select "input#apply-name"
    assert_select "input[name='proposed[list_price_cents]'][value=?]", "$16.99"
    assert_select "input[name='product[lock_version]']"
    assert_select "input[name=candidate_id]"
    assert_select ".admin-form-footer", text: /Apply selected fields/
    assert_select ".admin-form-footer a", text: "Cancel"
    assert_select ".bibliographic-review__selected", minimum: 1
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end
end
