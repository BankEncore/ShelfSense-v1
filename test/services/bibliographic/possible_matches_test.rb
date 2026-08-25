# frozen_string_literal: true

require "test_helper"

class Bibliographic::PossibleMatchesTest < ActiveSupport::TestCase
  setup do
    @actor = actor_user
  end

  test "classifies exact, strong, and weak matches" do
    exact = Products::Create.call(
      attributes: { name: "Exact Title", status: "draft" },
      actor: @actor,
      industry_identifier: FIXTURE_ISBN13
    )
    strong = Products::Create.call(
      attributes: {
        name: "The Left Hand of Darkness",
        subtitle: "50th Anniversary Edition",
        status: "draft",
        contribution_rows: [ { "display_name" => "Ursula K. Le Guin", "role" => "author" } ]
      },
      actor: @actor
    )
    weak = Products::Create.call(
      attributes: { name: "The Left Hand of Darkness Study Guide", status: "draft" },
      actor: @actor
    )

    result = Bibliographic::PossibleMatches.call(candidate: bibliographic_candidate)

    assert_includes result.exact_products.map(&:id), exact.id
    assert_includes result.strong.map(&:id), strong.id
    assert_includes result.weak.map(&:id), weak.id
    assert_not_includes result.strong.map(&:id), exact.id
    assert_not_includes result.weak.map(&:id), strong.id
  end
end
