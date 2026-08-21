# frozen_string_literal: true

require "test_helper"

class Products::AdminIndexQueryTest < ActiveSupport::TestCase
  setup do
    @actor = actor_user
    @alpha = Products::Create.call(
      attributes: { name: "Alpha Book", status: "active" },
      actor: @actor
    )
    @beta = Products::Create.call(
      attributes: { name: "Beta Guide", status: "draft" },
      actor: @actor
    )
    @category = merchandise_category(name: "Fiction")
    @beta.update!(merchandise_category: @category)
  end

  test "searches by name contains and identifier prefix" do
    by_name = Products::AdminIndexQuery.call(q: "alpha")
    assert_equal [ @alpha.id ], by_name.records.map(&:id)

    prefix = @beta.primary_identifier[0, 6]
    by_id = Products::AdminIndexQuery.call(q: prefix)
    assert_includes by_id.records.map(&:id), @beta.id
  end

  test "escapes like wildcards in q" do
    wild = Products::Create.call(
      attributes: { name: "100% Cotton", status: "draft" },
      actor: @actor
    )
    result = Products::AdminIndexQuery.call(q: "%")
    assert_includes result.records.map(&:id), wild.id
    assert_equal 1, result.records.count { |p| p.name.include?("%") }
  end

  test "filters status and category conjunctively" do
    result = Products::AdminIndexQuery.call(
      status: "draft",
      merchandise_category_id: @category.id
    )
    assert_equal [ @beta.id ], result.records.map(&:id)
  end

  test "orders by name and id and clamps page" do
    result = Products::AdminIndexQuery.call(page: 0)
    assert_equal 1, result.page
    assert_equal [ @alpha.name, @beta.name ].sort, result.records.map(&:name)

    high = Products::AdminIndexQuery.call(page: 999)
    assert_equal 1, high.page
  end
end
