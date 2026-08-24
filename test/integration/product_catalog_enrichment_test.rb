# frozen_string_literal: true

require "test_helper"

class ProductCatalogEnrichmentTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @admin = @bootstrap[:administrator]
    @store = @bootstrap[:store]
    @associate = User.create!(
      username: "associate",
      display_name: "Associate User",
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    RoleAssignment.create!(
      user: @associate,
      role: Role.find_by!(key: "associate"),
      store: @store,
      assigned_by: @admin,
      effective_at: Time.current
    )
  end

  test "catalog search uses an existing product instead of creating a duplicate" do
    product = Products::Create.call(
      attributes: { name: "Already Carried", status: "draft" },
      actor: @admin,
      industry_identifier: FIXTURE_ISBN13
    )
    sign_in_as("admin")

    stub_bibliographic_provider(FakeIsbnDbProvider.new(candidates: [ bibliographic_candidate ])) do
      post admin_product_catalog_searches_path, params: { catalog_search: { q: FIXTURE_ISBN13 } }
      assert_redirected_to admin_product_path(product)
    end
  end

  test "unknown ISBN lists candidates and create-from-candidate reserves the industry identifier" do
    sign_in_as("admin")
    provider = FakeIsbnDbProvider.new(candidates: [ bibliographic_candidate ])

    stub_bibliographic_provider(provider) do
      get new_admin_product_catalog_search_path
      assert_response :success

      post admin_product_catalog_searches_path, params: { catalog_search: { q: FIXTURE_ISBN13 } }
      assert_response :success
      assert_match(/The Left Hand of Darkness/, response.body)
      assert_match(/Use this book/, response.body)

      get new_admin_product_path, params: { isbn13: FIXTURE_ISBN13, lookup_key: "isbn:#{FIXTURE_ISBN13}" }
      assert_response :success
      assert_match(/The Left Hand of Darkness/, response.body)
      assert_select "input#product_industry_identifier[value=?]", FIXTURE_ISBN13

      post admin_products_path, params: {
        candidate_isbn13: FIXTURE_ISBN13,
        candidate_lookup_key: "isbn:#{FIXTURE_ISBN13}",
        product: {
          name: "The Left Hand of Darkness",
          status: "draft",
          industry_identifier: FIXTURE_ISBN13,
          publisher_name: "Ace",
          list_price: "16.99",
          cover_image_url: "https://images.isbndb.com/covers/81/25/9780441478125.jpg",
          contribution_rows: [ { display_name: "Ursula K. Le Guin", role: "author" } ]
        }
      }
      assert_response :redirect
    end

    created = Product.find_by!(industry_identifier: FIXTURE_ISBN13)
    assert created.primary_identifier.start_with?("222")
    assert_equal "Ace", created.publisher.name
    follow_redirect!
    assert_equal 1, created.product_contributions.count
    assert_equal "Ursula K. Le Guin", created.product_contributions.first.contributor.display_name
    assert_select ".product-identity__contributors", text: /Ursula K. Le Guin/
    assert_select "img.product-cover[src=?]", "https://images.isbndb.com/covers/81/25/9780441478125.jpg"
    assert_select "dt", text: "Imprint", count: 0
    assert_select "dt", text: "Series", count: 0
    assert_match(/isbndb/, response.body)

    event = AuditEvent.where(action: "products.enrich", subject_id: created.id).last
    payload = [ event.after_values, event.before_values, event.metadata ].to_json
    assert_no_match(/ISBNDB_API_KEY|test-key|image_original|other_isbns/, payload)
  end

  test "refresh does not overwrite curated list price without confirmation" do
    product = Products::CreateFromCandidate.call(
      candidate: bibliographic_candidate,
      actor: @admin,
      attributes: { name: "Staff title", list_price_cents: 2500 }
    )
    assert_includes product.bibliographic_curated_fields, "name"
    assert_includes product.bibliographic_curated_fields, "list_price_cents"

    sign_in_as("admin")
    stub_bibliographic_provider(FakeIsbnDbProvider.new(candidates: [ bibliographic_candidate ])) do
      get admin_product_path(product)
      assert_response :success
      assert_match(/Refresh bibliographic data/, response.body)

      post refresh_bibliography_admin_product_path(product)
      assert_redirected_to admin_product_path(product)
    end

    product.reload
    assert_equal "Staff title", product.name
    assert_equal 2500, product.list_price_cents
    assert_equal "Paperback", product.binding

    event = AuditEvent.where(action: "products.refresh", subject_id: product.id).last
    assert_equal "isbndb", event.after_values["bibliographic_provider"]
    assert_equal FIXTURE_ISBN13, event.after_values["bibliographic_provider_key"]
    assert_includes event.after_values["applied_fields"], "binding"
    assert_not_includes event.after_values["applied_fields"], "list_price_cents"
    assert_no_match(/ISBNDB_API_KEY/, event.after_values.to_json)
  end

  test "associates cannot search the catalog or refresh bibliography" do
    product = Products::Create.call(
      attributes: { name: "Viewable", status: "draft" },
      actor: @admin,
      industry_identifier: FIXTURE_ISBN13
    )
    sign_in_as("associate")

    get new_admin_product_catalog_search_path
    assert_redirected_to root_path

    post admin_product_catalog_searches_path, params: { catalog_search: { q: FIXTURE_ISBN13 } }
    assert_redirected_to root_path

    post refresh_bibliography_admin_product_path(product)
    assert_redirected_to root_path
    assert_equal "denied", AuditEvent.where(action: "authorization.denied").order(:created_at).last.outcome
    assert_nil AuditEvent.find_by(action: "products.refresh", subject_id: product.id)
  end

  test "POS does not auto-create from an unknown ISBN" do
    result = Pos::ResolveMerchandiseForSale.call(store: @store, identifier: FIXTURE_ISBN13)
    assert_equal :unavailable, result.outcome
    assert_nil Product.find_by(industry_identifier: FIXTURE_ISBN13)
  end

  test "product index finds a contributor and the show page lists provenance" do
    product = Products::CreateFromCandidate.call(candidate: bibliographic_candidate, actor: @admin)
    sign_in_as("admin")

    get admin_products_path, params: { q: "Le Guin" }
    assert_response :success
    assert_match(/The Left Hand of Darkness/, response.body)

    get admin_product_path(product)
    assert_response :success
    assert_match(/Ace/, response.body)
    assert_select ".product-identity__contributors", text: /Ursula K. Le Guin/
    assert_match(/isbndb/, response.body)
    assert_match(/Refresh bibliographic data/, response.body)
  end

  test "create-from-candidate keeps candidate contributors when submitted rows are blank" do
    sign_in_as("admin")
    stub_bibliographic_provider(FakeIsbnDbProvider.new(candidates: [ bibliographic_candidate ])) do
      post admin_product_catalog_searches_path, params: { catalog_search: { q: FIXTURE_ISBN13 } }
      get new_admin_product_path, params: { isbn13: FIXTURE_ISBN13, lookup_key: "isbn:#{FIXTURE_ISBN13}" }

      post admin_products_path, params: {
        candidate_isbn13: FIXTURE_ISBN13,
        candidate_lookup_key: "isbn:#{FIXTURE_ISBN13}",
        product: {
          name: "The Left Hand of Darkness",
          status: "draft",
          industry_identifier: FIXTURE_ISBN13,
          contribution_rows: {
            "0" => { display_name: "", role: "author" },
            "1" => { display_name: "", role: "author" },
            "2" => { display_name: "", role: "illustrator" }
          }
        }
      }
      assert_response :redirect
    end

    created = Product.find_by!(industry_identifier: FIXTURE_ISBN13)
    assert_equal [ "Ursula K. Le Guin" ], created.product_contributions.map { |row| row.contributor.display_name }
  end

  test "sideline product show omits contributor subtitle and publication" do
    product = Products::Create.call(
      attributes: { name: "Ceramic Mug", status: "draft", brand_name: "ShelfSense" },
      actor: @admin
    )
    sign_in_as("admin")

    get admin_product_path(product)
    assert_response :success
    assert_match(/Ceramic Mug/, response.body)
    assert_select ".product-identity__contributors", count: 0
    assert_select "h2", text: "Publication", count: 0
    assert_select "img.product-cover", count: 0
    assert_select "dt", text: "Brand"
    assert_select "dd", text: "ShelfSense"
  end

  private

  def sign_in_as(username)
    delete session_path
    follow_redirect! while response.redirect?
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
    follow_redirect! if response.redirect?
  end
end
