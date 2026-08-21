# frozen_string_literal: true

require "test_helper"

class ProductReactivateTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @admin = @bootstrap[:administrator]
    @product = Products::Create.call(
      attributes: { name: "Discontinued Book", status: "active" },
      actor: @admin
    )
    @product.update!(status: "discontinued")
  end

  test "reactivates a discontinued product" do
    sign_in_as("admin")

    post reactivate_admin_product_path(@product)
    assert_redirected_to admin_product_path(@product)
    assert_equal "active", @product.reload.status
    assert_equal "succeeded", AuditEvent.where(action: "products.reactivate").order(:created_at).last.outcome
  end

  test "rejects reactivation when merchandise category is inactive" do
    category = merchandise_category(name: "Soon Inactive", code: "soon_inactive", active: true)
    @product.update!(merchandise_category: category)
    category.update!(active: false)
    sign_in_as("admin")

    post reactivate_admin_product_path(@product)
    assert_redirected_to admin_product_path(@product)
    follow_redirect!
    assert_match(/merchandise category must be active/i, response.body)
    assert_equal "discontinued", @product.reload.status
  end

  test "rejects reactivation when product is not discontinued" do
    @product.update!(status: "active")
    sign_in_as("admin")

    post reactivate_admin_product_path(@product)
    assert_redirected_to admin_product_path(@product)
    follow_redirect!
    assert_match(/Only discontinued products/i, response.body)
  end

  private

  def sign_in_as(username)
    delete session_path
    follow_redirect! while response.redirect?
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
    follow_redirect! if response.redirect?
  end
end
