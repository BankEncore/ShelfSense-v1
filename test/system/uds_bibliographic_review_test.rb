# frozen_string_literal: true

require "application_system_test_case"

class UdsBibliographicReviewTest < ApplicationSystemTestCase
  setup do
    @bootstrap = bootstrap!
    @actor = @bootstrap[:administrator]
    ProductForms::Catalog.seed!
    sign_in_admin(actor: @actor)
  end

  test "bibliographic review stable and invalid apply pass axe" do
    product = Products::Create.call(attributes: { name: "Existing title", status: "draft" }, actor: @actor)
    candidate = bibliographic_candidate
    Bibliographic::LookupCache.store("isbn:#{candidate.isbn13}", [ candidate ], ttl: 1.hour)

    visit bibliographic_review_admin_product_path(product, candidate_id: candidate.candidate_id)
    assert_text "Review bibliographic data"
    assert_text "Current"
    assert_text "Proposed"
    assert_axe_clean(surface: :bibliographic_review)

    page.execute_script("document.querySelector('input[name=\"product[lock_version]\"]').value = '-1'")
    click_on "Apply selected fields"
    assert_selector ".form-errors, .alert, [role='alert']", wait: 3
    assert_axe_clean(surface: :bibliographic_review)
  end
end
