# frozen_string_literal: true

require "test_helper"

class ProductForms::BindingMigratorTest < ActiveSupport::TestCase
  test "classifies mapped and unmapped binding text for the migration report" do
    mapped = ProductForms::BindingMigrator.classify(id: "p1", binding: "Paperback")
    assert_equal "PB", mapped.code
    assert_not mapped.legacy

    leftover = ProductForms::BindingMigrator.classify(id: "p2", binding: "saddle stitch")
    assert_nil leftover.code
    assert leftover.legacy
  end
end
