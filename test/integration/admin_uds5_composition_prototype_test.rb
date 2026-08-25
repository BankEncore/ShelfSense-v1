# frozen_string_literal: true

require "test_helper"

class AdminUds5CompositionPrototypeTest < ActionDispatch::IntegrationTest
  setup do
    bootstrap!
  end

  test "unsigned-in request is redirected to sign in" do
    get admin_uds5_composition_prototype_path
    assert_redirected_to new_session_path
  end

  test "production products page does not render the disposable fixture" do
    sign_in_as("admin")
    get admin_products_path
    assert_response :success
    assert_no_match(/uds-5-composition-prototype/, response.body)
    assert_no_match(/UDS-5.1 composition prototype/, response.body)
  end

  test "renders composition primitives without a runtime font CDN" do
    sign_in_as("admin")
    get admin_uds5_composition_prototype_path
    assert_response :success

    assert_select ".uds-5-composition-prototype"
    assert_select "[data-uds5-header=full] .type-page-title", text: /Left Hand of Darkness/
    assert_select "[data-uds5-header=full] .type-eyebrow", text: "Merchandise"
    assert_select "[data-uds5-header=full] .page-header__subtitle", count: 1
    assert_select "[data-uds5-header=full] .page-header__metadata", text: /2220000001846/
    assert_select "[data-uds5-header=full] .page-header__status"
    assert_select "[data-uds5-header=full] .page-header__actions"
    assert_select "[data-uds5-header=minimal] .page-header__subtitle", count: 0
    assert_select "[data-uds5-header=minimal] .page-header__status", count: 0
    assert_select ".metric-strip"
    assert_select ".surface--flush", minimum: 1
    assert_select ".form-section__grid"
    assert_select ".admin-form-footer"
    assert_select ".data-table .cell-primary"
    assert_select ".data-table .cell-identifier"
    assert_select "[aria-invalid=true]"
    assert_select ".type-brand"
    assert_select ".type-record-title"
    assert_select ".type-identifier"
    assert_select ".type-tabular"
  end

  test "application css packages serif and keeps receipt mono distinct" do
    css = Rails.root.join("app/assets/stylesheets/application.css").read
    assert_match "Source Serif 4", css
    assert_match "--font-serif", css
    assert_match "--font-mono", css
    assert_match "--font-receipt", css
    assert_match "Inconsolata", css
    refute_match "fonts.googleapis.com", css
    refute_match "cdn.jsdelivr.net", css
    assert_match %r{--font-receipt:\s*"Inconsolata"}, css
    refute_match %r{--font-mono:[^;]*Inconsolata}, css
  end

  test "product family templates do not set font-family" do
    Dir[Rails.root.join("app/views/admin/products/**/*.html.erb")].each do |path|
      refute_match(/font-family/, File.read(path), "#{path} must not set font-family")
    end
    Dir[Rails.root.join("app/views/admin/product_catalog_searches/**/*.html.erb")].each do |path|
      refute_match(/font-family/, File.read(path), "#{path} must not set font-family")
    end
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end
end
