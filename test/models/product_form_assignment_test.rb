# frozen_string_literal: true

require "test_helper"

class ProductFormAssignmentTest < ActiveSupport::TestCase
  setup do
    @actor = actor_user
    ProductForms::Catalog.seed!
  end

  test "inactive product forms cannot be newly assigned" do
    form = ProductForm.find_by!(code: "PB")
    form.update!(active: false)

    error = assert_raises(Products::Create::Error) do
      Products::Create.call(
        attributes: { name: "Inactive form", status: "draft", product_form_id: form.id },
        actor: @actor
      )
    end
    assert_match(/active product form/i, error.message)
  end

  test "existing inactive assignment is retained on unrelated edits" do
    form = ProductForm.find_by!(code: "HC")
    product = Products::Create.call(
      attributes: { name: "Cloth book", status: "draft", product_form_id: form.id },
      actor: @actor
    )
    form.update!(active: false)

    Products::Update.call(
      product: product,
      attributes: { name: "Cloth book revised", lock_version: product.lock_version },
      actor: @actor
    )
    assert_equal form.id, product.reload.product_form_id
  end
end
