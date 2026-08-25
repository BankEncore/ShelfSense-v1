# frozen_string_literal: true

require "test_helper"

class Bibliographic::ProductFormMapperTest < ActiveSupport::TestCase
  test "maps conservative binding text to seed codes" do
    assert_equal "HC", Bibliographic::ProductFormMapper.code_for("Hardcover")
    assert_equal "HC", Bibliographic::ProductFormMapper.code_for("hard cover")
    assert_equal "TC", Bibliographic::ProductFormMapper.code_for("trade cloth")
    assert_equal "PB", Bibliographic::ProductFormMapper.code_for("paperback")
    assert_equal "TP", Bibliographic::ProductFormMapper.code_for("trade paperback")
    assert_equal "MM", Bibliographic::ProductFormMapper.code_for("mass market")
    assert_equal "BB", Bibliographic::ProductFormMapper.code_for("board book")
    assert_equal "EB", Bibliographic::ProductFormMapper.code_for("e-book")
    assert_equal "AU", Bibliographic::ProductFormMapper.code_for("audiobook")
  end

  test "maps an exact known code" do
    assert_equal "PB", Bibliographic::ProductFormMapper.code_for("PB")
    assert_equal "OT", Bibliographic::ProductFormMapper.code_for("OT")
  end

  test "omits unknown text and never infers OT" do
    assert_nil Bibliographic::ProductFormMapper.code_for("saddle stitch")
    assert_nil Bibliographic::ProductFormMapper.code_for("other")
    assert_nil Bibliographic::ProductFormMapper.code_for("unknown format")
  end
end
