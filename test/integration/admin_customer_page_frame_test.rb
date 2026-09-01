# frozen_string_literal: true

require "test_helper"

class AdminCustomerPageFrameTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @customer = Customer.create!(
      display_name: "Frame Reader",
      given_name: "Frame",
      family_name: "Reader",
      email: "frame.reader@example.com",
      phone: "555-010-0001",
      preferred_contact_method: "email",
      notes: "Keep me"
    )
  end

  test "index uses the page frame at standard width with surfaced tools" do
    sign_in_as("admin")
    get admin_customers_path
    assert_response :success
    assert_page_frame modifier: "standard"
    assert_select ".admin-page__tools form.filters.surface.customer-filters", count: 1
    assert_select ".admin-page__body form.filters", count: 0
    assert_select ".admin-page__tools input[name=q]"
    assert_select ".admin-page__tools select[name=lifecycle]"
    assert_select ".page-header__title", text: "Customers"
    assert_select "a", text: "New customer"
    assert_select "th", text: "Name"
    assert_select "th", text: "Email"
    assert_select "th", text: "Phone"
    assert_select "th", text: "Status"
    assert_select "td a", text: "Frame Reader"
    assert_select "main.app-content.app-content--wide", count: 0
  end

  test "filtered index retains query params inside tools and filtered empty copy" do
    sign_in_as("admin")
    get admin_customers_path, params: { q: "Jordan", lifecycle: "merged" }
    assert_response :success
    assert_page_frame modifier: "standard"
    assert_select ".admin-page__tools form.filters.surface.customer-filters"
    assert_select "input[name=q][value=Jordan]"
    assert_select "select[name=lifecycle] option[selected][value=merged]"
    assert_select ".empty-state__title", text: "No matching customers"
    assert_select ".empty-state", text: /Try a different name, email, or phone/
  end

  test "unfiltered empty index keeps no-customers copy" do
    Customer.delete_all
    sign_in_as("admin")
    get admin_customers_path
    assert_response :success
    assert_page_frame modifier: "standard"
    assert_select ".empty-state__title", text: "No customers yet"
    assert_select ".empty-state", text: /Create a customer to attach requests/
  end

  test "index still annotates matched former records" do
    survivor = Customer.create!(display_name: "Canonical Survivor", email: "canon@example.com", phone: "555-333-0001")
    source = Customer.create!(display_name: "Former Alias", email: "former@example.com", phone: "555-333-0002")
    Customers::MergeCustomers.call(
      source: source,
      survivor: survivor,
      actor: @bootstrap[:administrator],
      reason: "dedupe",
      idempotency_key: SecureRandom.uuid_v7
    )
    sign_in_as("admin")

    get admin_customers_path, params: { q: "555-333-0002" }
    assert_response :success
    assert_page_frame modifier: "standard"
    assert_select ".admin-page__tools form.filters.surface.customer-filters"
    assert_includes response.body, "Canonical Survivor"
    assert_includes response.body, "matched former record"
    assert_select "th", text: "Name"
    assert_select "th", text: "Email"
    assert_select "th", text: "Phone"
    assert_select "th", text: "Status"
  end

  test "show uses the page frame at standard width without product composition" do
    sign_in_as("admin")
    get admin_customer_path(@customer)
    assert_response :success
    assert_page_frame modifier: "standard"
    assert_select ".admin-page__tools", count: 0
    assert_select ".page-header__title", text: "Frame Reader"
    assert_select "a", text: "Edit"
    assert_select ".definition-list"
    assert_select "h2", text: "Merge into another customer"
    assert_select "h2", text: "Stored value"
    assert_select "h2", text: "Associated gift cards"
    assert_select "h2", text: "Recent requests"
    assert_select ".content-grid", count: 0
    assert_select ".product-panels", count: 0
    assert_select ".metric-strip", count: 0
  end

  test "show merge form still targets unmigrated merge review" do
    survivor = Customer.create!(display_name: "Merge Survivor", email: "mv@example.com", phone: "555-800-0001")
    sign_in_as("admin")

    get admin_customer_path(@customer)
    assert_response :success
    assert_page_frame modifier: "standard"
    assert_select "form[action=?][method=get]", merge_review_admin_customer_path(@customer) do
      assert_select "input[name=survivor_id]"
      assert_select "input[type=submit][value='Review merge']"
    end

    get merge_review_admin_customer_path(@customer), params: { survivor_id: survivor.id }
    assert_response :success
    assert_select ".admin-page", count: 0
    assert_select "main[class='app-content']"
    assert_select "main.app-content.app-content--standard", count: 0
    assert_select "main.app-content.app-content--wide", count: 0
    assert_select "h1", text: "Merge review"
    assert_select "h2", text: "Survivor (kept)"
    assert_select "h2", text: "Source (becomes alias)"
    assert_includes response.body, survivor.admin_label
    assert_includes response.body, @customer.admin_label
  end

  test "new uses the page frame at standard width and keeps the frozen form" do
    sign_in_as("admin")
    get new_admin_customer_path
    assert_response :success
    assert_page_frame modifier: "standard"
    assert_frozen_customer_form persisted: false
  end

  test "edit uses the page frame at standard width and keeps the frozen form" do
    sign_in_as("admin")
    get edit_admin_customer_path(@customer)
    assert_response :success
    assert_page_frame modifier: "standard"
    assert_frozen_customer_form persisted: true, customer: @customer
  end

  test "failed create redisplays standard with retained values" do
    sign_in_as("admin")
    post admin_customers_path, params: {
      customer: {
        display_name: "",
        given_name: "",
        family_name: "",
        email: "kept@example.com",
        phone: "555-010-0099",
        preferred_contact_method: "email",
        notes: "Kept notes"
      },
      idempotency_key: SecureRandom.uuid_v7
    }
    assert_response :unprocessable_entity
    assert_page_frame modifier: "standard"
    assert_select "input[name='customer[email]'][value='kept@example.com']"
    assert_select "input[name='customer[phone]'][value='555-010-0099']"
    assert_select "select[name='customer[preferred_contact_method]'] option[selected][value=email]"
    assert_select "textarea[name='customer[notes]']", text: "Kept notes"
    assert_frozen_customer_form persisted: false, require_idempotency: false
  end

  test "failed update redisplays standard with retained values" do
    sign_in_as("admin")
    patch admin_customer_path(@customer), params: {
      customer: {
        display_name: "",
        given_name: "",
        family_name: "",
        email: "kept.update@example.com",
        phone: @customer.phone,
        preferred_contact_method: "phone",
        notes: "Kept update notes",
        lock_version: @customer.lock_version
      }
    }
    assert_response :unprocessable_entity
    assert_page_frame modifier: "standard"
    assert_select "input[name='customer[email]'][value='kept.update@example.com']"
    assert_select "textarea[name='customer[notes]']", text: "Kept update notes"
    assert_frozen_customer_form persisted: true, customer: @customer
  end

  test "duplicate detection redisplays the frame and possible duplicates" do
    Customer.create!(display_name: "Dup Person", email: "dup@example.com", phone: "555-777-7777")
    sign_in_as("admin")

    post admin_customers_path, params: {
      customer: { display_name: "Someone Else", email: "dup@example.com" },
      idempotency_key: SecureRandom.uuid_v7
    }
    assert_response :unprocessable_entity
    assert_page_frame modifier: "standard"
    assert_includes response.body, "Possible duplicates"
    assert_select "input[name='customer[display_name]'][value='Someone Else']"
    assert_select "input[name='customer[email]'][value='dup@example.com']"
    assert_select "input[name=acknowledge_duplicates]"
    assert_frozen_customer_form persisted: false, require_idempotency: false
  end

  test "unmigrated users index has no width modifier" do
    sign_in_as("admin")
    get admin_users_path
    assert_response :success
    assert_select "main[class='app-content']"
    assert_select ".admin-page", count: 0
  end

  test "customer-scoped tools CSS does not change width tokens" do
    css = Rails.root.join("app/assets/stylesheets/application.css").read
    assert_match(/\.admin-page__tools\s*>\s*\.customer-filters\s*\{\s*margin-bottom:\s*0;/, css)
    assert_match(/\.admin-page \.definition-list dd/, css)
    assert_match(/--content-max:\s*72rem/, css[/:root\s*\{[^}]+\}/m])
    assert_match(/--admin-content-wide:\s*90rem/, css[/:root\s*\{[^}]+\}/m])
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end

  def assert_page_frame(modifier:)
    assert_select ".admin-page", count: 1
    assert_select "main.app-content .admin-page", count: 1
    assert_select ".admin-page .admin-page", count: 0
    assert_select "h1", count: 1
    assert_select "main[class='app-content app-content--#{modifier}']"
  end

  def assert_frozen_customer_form(persisted:, customer: nil, require_idempotency: !persisted)
    assert_select "form.form"
    assert_select "input[name='customer[given_name]']"
    assert_select "input[name='customer[family_name]']"
    assert_select "input[name='customer[display_name]']"
    assert_select "input[name='customer[email]']"
    assert_select "input[name='customer[phone]']"
    assert_select "select[name='customer[preferred_contact_method]']"
    assert_select "textarea[name='customer[notes]']"
    assert_select "input[name='customer[lock_version]'][type=hidden]"
    if persisted
      assert_select "form.form button", text: "Save Changes"
      assert_select "a", text: "Cancel" do |links|
        assert_equal admin_customer_path(customer), links.first["href"]
      end
    else
      assert_select "input[name=idempotency_key][type=hidden]" if require_idempotency
      assert_select "form.form button", text: "Create Customer"
      assert_select "a", text: "Cancel" do |links|
        assert_equal admin_customers_path, links.first["href"]
      end
    end
  end
end
