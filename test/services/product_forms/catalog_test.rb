# frozen_string_literal: true

require "test_helper"

class ProductForms::CatalogTest < ActiveSupport::TestCase
  test "seed is complete and idempotent" do
    ProductForms::Catalog.seed!
    first = ProductForm.order(:code).pluck(:code, :name, :display_order, :active)
    assert_equal ProductForms::Catalog::SEEDS.size, ProductForm.count

    ProductForms::Catalog.seed!
    assert_equal first, ProductForm.order(:code).pluck(:code, :name, :display_order, :active)
  end

  test "seed does not overwrite a staff-edited name or reactivate a deactivated form" do
    ProductForms::Catalog.seed!
    form = ProductForm.find_by!(code: "PB")
    form.update!(name: "Softcover (store label)", active: false)

    ProductForms::Catalog.seed!
    form.reload
    assert_equal "Softcover (store label)", form.name
    assert_not form.active?
  end
end
