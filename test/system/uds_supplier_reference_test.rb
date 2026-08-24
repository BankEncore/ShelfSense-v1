# frozen_string_literal: true

require "application_system_test_case"

class UdsSupplierReferenceTest < ApplicationSystemTestCase
  setup do
    @bootstrap = bootstrap!
    @actor = @bootstrap[:administrator]
    @supplier = Supplier.create!(name: "UDS Supplier", code: "uds_#{SecureRandom.hex(3)}")
    sign_in_admin(actor: @actor)
  end

  test "supplier index passes axe and layout smoke" do
    visit admin_suppliers_path
    assert_text "Suppliers"
    assert_axe_clean(surface: :supplier_admin)
    uds_layout_smoke(surface: :supplier_admin, scroll_selector: ".table-scroll")
    assert_reduced_motion_smoke(surface: :supplier_admin)
    assert_forced_colors_smoke(surface: :supplier_admin)
  end

  test "supplier new form invalid state passes axe" do
    visit new_admin_supplier_path
    click_on "Create Supplier"
    assert_selector ".form-errors"
    assert_axe_clean(surface: :supplier_admin)
  end

  test "supplier show and edit pass axe" do
    visit admin_supplier_path(@supplier)
    assert_axe_clean(surface: :supplier_admin)

    click_on "Edit"
    assert_axe_clean(surface: :supplier_admin)
  end

  test "supplier keyboard focus reaches primary actions" do
    visit admin_suppliers_path
    assert_link "New supplier"
    find("a", text: @supplier.admin_label, match: :first).click
    assert_current_path admin_supplier_path(@supplier)
    assert_link "Edit"
  end
end
