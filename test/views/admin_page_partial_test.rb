# frozen_string_literal: true

require "test_helper"

class AdminPagePartialTest < ActionView::TestCase
  helper AdminPageHelper
  helper ActionButtonHelper

  test "renders region order context header tools body" do
    render layout: "admin/shared/page", locals: {
      width: :standard,
      title: "Reasons",
      crumbs: [ { name: "Home", path: "/" }, { name: "Reasons" } ],
      tools: "<p class=\"tools-probe\">Tools</p>".html_safe
    } do
      "<p class=\"body-probe\">Body</p>".html_safe
    end

    html = rendered
    context_at = html.index("admin-page__context")
    header_at = html.index("admin-page__header")
    tools_at = html.index("admin-page__tools")
    body_at = html.index("admin-page__body")

    assert context_at
    assert header_at
    assert tools_at
    assert body_at
    assert_operator context_at, :<, header_at
    assert_operator header_at, :<, tools_at
    assert_operator tools_at, :<, body_at
    assert_select "h1.page-header__title", text: "Reasons"
    assert_select "h1", count: 1
    assert_select "nav[aria-label=Breadcrumb]"
  end

  test "omits context and tools wrappers when those locals are absent" do
    render layout: "admin/shared/page", locals: { width: :narrow, title: "New reason" } do
      "<p class=\"body-probe\">Body</p>".html_safe
    end

    assert_select ".admin-page__context", count: 0
    assert_select ".admin-page__tools", count: 0
    assert_select ".admin-page__header h1", text: "New reason"
    assert_select ".admin-page__body .body-probe", text: "Body"
  end

  test "preserves tools HTML without escaping" do
    render layout: "admin/shared/page", locals: {
      width: :standard,
      title: "Reasons",
      tools: "<form class=\"tools-probe\"><input type=\"search\"></form>".html_safe
    } do
      "body".html_safe
    end

    assert_select ".admin-page__tools form.tools-probe input[type=search]"
  end

  test "does not set the document title capture" do
    render layout: "admin/shared/page", locals: { width: :standard, title: "Reasons" } do
      "body".html_safe
    end

    assert_not content_for?(:title)
  end

  test "rejects a missing width" do
    error = assert_raises(ActionView::Template::Error) do
      render layout: "admin/shared/page", locals: { title: "Reasons" } do
        "body".html_safe
      end
    end

    assert_match(/width is required/, error.message)
  end

  test "rejects a blank title" do
    error = assert_raises(ActionView::Template::Error) do
      render layout: "admin/shared/page", locals: { width: :standard, title: "  " } do
        "body".html_safe
      end
    end

    assert_match(/title is required/, error.message)
  end

  test "rejects a missing title" do
    error = assert_raises(ActionView::Template::Error) do
      render layout: "admin/shared/page", locals: { width: :standard } do
        "body".html_safe
      end
    end

    assert_match(/title is required/, error.message)
  end
end
