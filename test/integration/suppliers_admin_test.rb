# frozen_string_literal: true

require "test_helper"

class SuppliersAdminTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
  end

  test "admin can create a supplier with audit" do
    sign_in_as("admin")

    post admin_suppliers_path, params: {
      supplier: {
        code: "ingram",
        name: "Ingram",
        email: "orders@example.com"
      }
    }
    supplier = Supplier.find_by!(code: "ingram")
    assert_redirected_to admin_supplier_path(supplier)
    assert_equal "Ingram", supplier.name
    assert AuditEvent.exists?(action: "suppliers.create", subject_id: supplier.id)
  end

  test "associate can view but not manage suppliers" do
    associate = User.create!(
      username: "clerk_sup",
      display_name: "Clerk",
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    RoleAssignment.create!(
      user: associate,
      role: Role.find_by!(key: "associate"),
      store: Store.first,
      assigned_by: User.find_by!(username: "admin"),
      effective_at: Time.current
    )

    sign_in_as("clerk_sup")
    get admin_suppliers_path
    assert_response :success

    post admin_suppliers_path, params: {
      supplier: { code: "denied", name: "Denied" }
    }
    assert_redirected_to root_path
    assert_not Supplier.exists?(code: "denied")
  end

  test "variant page can add edit and remove preferred supplier sources" do
    sign_in_as("admin")
    store = @bootstrap[:store]
    actor = @bootstrap[:administrator]
    post store_selection_path, params: { store_id: store.id }

    tax = tax_class(code: "src_#{SecureRandom.hex(2)}")
    variant = pos_sellable_variant(actor: actor, tax_class: tax, name: "Source Variant")
    supplier = Supplier.create!(name: "Variant Supp", code: "vs_#{SecureRandom.hex(2)}")

    get admin_product_variant_path(variant)
    assert_response :success
    assert_match(/Supplier sources/, response.body)
    assert_match(/Add supplier source/, response.body)

    get new_admin_product_variant_supplier_variant_source_path(variant)
    assert_response :success
    assert_match(/Select supplier/, response.body)

    assert_difference -> { SupplierVariantSource.count }, 1 do
      post admin_product_variant_supplier_variant_sources_path(variant), params: {
        supplier_variant_source: {
          supplier_id: supplier.id,
          pricing_method: "direct_unit_cost",
          expected_unit_cost_cents: 525,
          organization_preferred: true,
          supplier_item_number: "VS-1"
        }
      }
    end
    source = SupplierVariantSource.order(:created_at).last
    assert_redirected_to admin_product_variant_path(variant)
    assert source.organization_preferred?
    assert_equal 525, source.expected_unit_cost_cents

    get admin_product_variant_path(variant)
    assert_match(/org preferred/, response.body)
    assert_match(supplier.name, response.body)

    patch admin_supplier_variant_source_path(source, return_to: "variant"), params: {
      supplier_variant_source: {
        pricing_method: "direct_unit_cost",
        expected_unit_cost_cents: 600,
        organization_preferred: true,
        lock_version: source.lock_version
      }
    }
    assert_redirected_to admin_product_variant_path(variant)
    assert_equal 600, source.reload.expected_unit_cost_cents

    post admin_supplier_variant_source_store_supplier_source_preferences_path(source, return_to: "variant"),
         params: { store_supplier_source_preference: { store_id: store.id } }
    assert_redirected_to admin_product_variant_path(variant)
    preference = StoreSupplierSourcePreference.find_by!(store: store, product_variant: variant)
    assert_equal source.id, preference.supplier_variant_source_id

    delete admin_supplier_variant_source_path(source, return_to: "variant")
    assert_redirected_to admin_product_variant_path(variant)
    assert_not source.reload.active?
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end
end
