# frozen_string_literal: true

require "test_helper"

class AdminPageHelperTest < ActionView::TestCase
  AdminPageHelper::ADMIN_PAGE_WIDTH_CLASSES.each do |mode, css_class|
    test "maps #{mode} from a symbol" do
      capture_admin_page_width!(mode)
      assert_equal css_class, content_for(:admin_page_width)
    end

    test "maps #{mode} from a string" do
      capture_admin_page_width!(mode.to_s)
      assert_equal css_class, content_for(:admin_page_width)
    end
  end

  test "rejects unknown widths without storing a capture" do
    error = assert_raises(ArgumentError) { capture_admin_page_width!(:bogus) }

    assert_match(/Unknown Admin page width :bogus/, error.message)
    assert_match(/narrow, standard, wide, workspace/, error.message)
    assert_not content_for?(:admin_page_width)
  end

  test "rejects a second width declaration" do
    capture_admin_page_width!(:standard)

    error = assert_raises(ArgumentError) { capture_admin_page_width!(:narrow) }

    assert_match(/already been set/, error.message)
    assert_equal "app-content--standard", content_for(:admin_page_width)
  end

  test "does not interpolate caller strings into the class list" do
    assert_raises(ArgumentError) { capture_admin_page_width!("standard extra") }
    assert_not content_for?(:admin_page_width)
  end
end
