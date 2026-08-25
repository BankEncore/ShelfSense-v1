# frozen_string_literal: true

require "test_helper"

class FormSectionPartialTest < ActionView::TestCase
  test "wraps title help and body without a grid by default" do
    render layout: "shared/form_section", locals: { title: "Identity", help: "Help copy" } do
      "<div class=\"form-field\">Name</div>".html_safe
    end

    assert_select "h2.section__title.type-section-title", text: "Identity"
    assert_select ".section__help.type-help", text: "Help copy"
    assert_select ".form-section__body .form-field", text: "Name"
    assert_select ".form-section__grid", count: 0
  end

  test "opts into a related-field grid" do
    render layout: "shared/form_section", locals: { title: "Identity", grid: true } do
      "<div class=\"form-field form-field--span-2\">Name</div>".html_safe
    end

    assert_select ".form-section__body.form-section__grid .form-field--span-2", text: "Name"
    assert_select ".section__help", count: 0
  end
end
