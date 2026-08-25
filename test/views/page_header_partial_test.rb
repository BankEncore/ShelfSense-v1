# frozen_string_literal: true

require "test_helper"

class PageHeaderPartialTest < ActionView::TestCase
  test "omits optional slots when they are absent" do
    render "shared/page_header", title: "Products"

    assert_select "h1.page-header__title.type-page-title", text: "Products"
    assert_select ".page-header__eyebrow", count: 0
    assert_select ".page-header__subtitle", count: 0
    assert_select ".page-header__metadata", count: 0
    assert_select ".page-header__status", count: 0
    assert_select ".page-header__actions", count: 0
  end

  test "renders extended slots when provided" do
    render "shared/page_header",
      title: "Edit product",
      eyebrow: "Merchandise",
      subtitle: "Catalog",
      metadata: "2220000001846",
      status: "<span class=\"status-badge\">Active</span>".html_safe,
      actions: "<a href=\"#\">Edit</a>".html_safe

    assert_select ".page-header__eyebrow.type-eyebrow", text: "Merchandise"
    assert_select ".page-header__subtitle.type-subtitle", text: "Catalog"
    assert_select ".page-header__metadata.type-metadata", text: "2220000001846"
    assert_select ".page-header__status", text: /Active/
    assert_select ".page-header__actions.actions a", text: "Edit"
  end
end
