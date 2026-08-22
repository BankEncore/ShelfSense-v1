# frozen_string_literal: true

require "test_helper"

class SupplierTest < ActiveSupport::TestCase
  test "normalizes code and rejects changes after create" do
    supplier = Supplier.create!(name: "Ingram Content", code: "Ingram Content")
    assert_equal "ingram_content", supplier.code

    supplier.code = "other"
    assert_not supplier.valid?
    assert_includes supplier.errors[:code], "cannot be changed after creation"
  end

  test "requires unique code and name" do
    Supplier.create!(name: "Baker & Taylor", code: "baker_taylor")
    duplicate = Supplier.new(name: "Other", code: "baker_taylor")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:code], "has already been taken"

    nameless = Supplier.new(code: "nameless")
    assert_not nameless.valid?
    assert_includes nameless.errors[:name], "can't be blank"
  end
end
