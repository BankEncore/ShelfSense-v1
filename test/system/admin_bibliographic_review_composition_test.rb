# frozen_string_literal: true

require "application_system_test_case"

class AdminBibliographicReviewCompositionSystemTest < ApplicationSystemTestCase
  setup do
    @bootstrap = bootstrap!
    @actor = @bootstrap[:administrator]
    ProductForms::Catalog.seed!
    @product = Products::Create.call(attributes: { name: "Existing title", status: "draft" }, actor: @actor)
    @candidate = bibliographic_candidate
    Bibliographic::LookupCache.store("isbn:#{@candidate.isbn13}", [ @candidate ], ttl: 1.hour)
    sign_in_admin(actor: @actor)
  end

  test "review comparison remains usable at 320 and zoom" do
    visit bibliographic_review_admin_product_path(@product, candidate_id: @candidate.candidate_id)
    assert_selector ".page-header__eyebrow", text: /product/i
    assert_selector ".form-section", text: "Identity"
    assert_selector ".bibliographic-review__selected", text: /Selected/i
    assert_field "proposed[list_price_cents]", with: "$16.99"
    assert_selector ".admin-form-footer", text: "Apply selected fields"

    with_viewport(width: 320, height: 568) do
      assert_selector "#review-name"
      assert_selector ".admin-form-footer", text: "Apply selected fields"
    end

    with_viewport(width: 1280, height: 720, zoom: 2) do
      assert_selector ".form-section", text: "Publication"
    end
  end
end
