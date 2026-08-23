# frozen_string_literal: true

require "test_helper"

class ActionButtonHelperTest < ActionView::TestCase
  test "action_link_to emits controlled classes on an anchor" do
    html = action_link_to("Cancel", "/products/1", style: :ghost, intent: :neutral)

    assert_select_html html, "a.btn.btn--ghost.btn--neutral.btn--standard[href='/products/1']", text: "Cancel"
    assert_select_html html, "a[class='btn btn--ghost btn--neutral btn--standard']"
  end

  test "action_link_to rejects method and caller class" do
    assert_raises(ArgumentError) do
      action_link_to("Cancel", "/products/1", style: :ghost, intent: :neutral, method: :delete)
    end
    assert_raises(ArgumentError) do
      action_link_to("Cancel", "/products/1", style: :ghost, intent: :neutral, class: "extra")
    end
  end

  test "action_link_to disabled strips Stimulus actions but keeps passive data attributes" do
    html = action_link_to(
      "Next",
      "/next",
      style: :outline,
      intent: :neutral,
      disabled: true,
      data: {
        action: "wizard#advance",
        wizard_target: "nextLink"
      },
      "aria-describedby": "why"
    )

    assert_select_html html, "span.btn.btn--outline.btn--neutral.btn--standard[aria-disabled=true]", text: "Next"
    assert_select_html html, "span[aria-describedby=why]"
    assert_select_html html, "span[data-wizard-target=nextLink]"
    assert_select_html html, "span[data-action]", count: 0
    assert_select_html html, "a", count: 0
  end

  test "action_link_to disabled renders a non-focusable span" do
    html = action_link_to(
      "Next",
      "/next",
      style: :outline,
      intent: :neutral,
      disabled: true,
      target: "_blank",
      rel: "noopener",
      "aria-describedby": "why"
    )

    assert_select_html html, "span.btn.btn--outline.btn--neutral.btn--standard[aria-disabled=true]", text: "Next"
    assert_select_html html, "span[aria-describedby=why]"
    assert_select_html html, "span[href]", count: 0
    assert_select_html html, "span[target]", count: 0
    assert_select_html html, "a", count: 0
  end

  test "action_button_to emits a standalone form with method override and CSRF" do
    html = action_button_to(
      "Deactivate",
      "/tender_types/1/deactivate",
      style: :outline,
      intent: :warning,
      method: :patch,
      form: { data: { turbo: false } },
      data: { test: "button" }
    )

    assert_select_html html, "form[action='/tender_types/1/deactivate'][method=post][data-turbo=false]"
    assert_select_html html, "form input[name=_method][value=patch]", count: 1
    assert_select_html html,
      "form button.btn.btn--outline.btn--warning.btn--standard[type=submit][data-test=button]",
      text: "Deactivate"
    # CSRF follows the test environment's forgery-protection setting.
    if ActionController::Base.allow_forgery_protection
      assert_select_html html, "form input[name=authenticity_token]", count: 1
    end
  end
  test "action_button_to requires method and rejects class smuggling" do
    assert_raises(ArgumentError) do
      action_button_to("Go", "/x", style: :solid, intent: :brand, method: nil)
    end
    assert_raises(ArgumentError) do
      action_button_to("Go", "/x", style: :solid, intent: :brand, method: :post, class: "x")
    end
    assert_raises(ArgumentError) do
      action_button_to("Go", "/x", style: :solid, intent: :brand, method: :post, form: { class: "x" })
    end
  end

  test "action_submit uses the form builder button without nesting a form" do
    html = form_with(url: "/products", scope: :product) do |f|
      action_submit(f, "Save Changes", style: :solid, intent: :brand, name: "commit", value: "save")
    end

    assert_select_html html, "form[action='/products']"
    assert_select_html html, "form form", count: 0
    assert_select_html html,
      "form button.btn.btn--solid.btn--brand.btn--standard[name=commit][value=save]",
      text: "Save Changes"
  end

  test "action_button emits type=button and preserves Stimulus bindings" do
    html = action_button(
      "Cash (F1)",
      style: :solid,
      intent: :brand,
      size: :large,
      data: {
        action: "register-workspace#chooseCash",
        register_workspace_target: "cashButton"
      },
      id: "cash-button"
    )

    assert_select_html html, "button#cash-button.btn.btn--solid.btn--brand.btn--large[type=button]"
    assert_select_html html, "button[data-action='register-workspace#chooseCash']"
    assert_select_html html, "button[data-register-workspace-target=cashButton]"
  end

  test "action_button rejects submit type" do
    assert_raises(ArgumentError) do
      action_button("Save", style: :solid, intent: :brand, type: :submit)
    end
  end

  test "allowlist accepts every valid style intent and size" do
    ActionButtonHelper::INTENTS_BY_STYLE.each do |style, intents|
      intents.each do |intent|
        ActionButtonHelper::SIZES.each do |size|
          html = action_button("Go", style:, intent:, size:)
          assert_select_html html, "button.btn.btn--#{style}.btn--#{intent}.btn--#{size}[type=button]"
        end
      end
    end
  end

  test "invalid style intent pairs and tokens raise" do
    assert_raises(ArgumentError) { action_button("Go", style: :ghost, intent: :brand) }
    assert_raises(ArgumentError) { action_button("Go", style: :solid, intent: :neutral) }
    assert_raises(ArgumentError) { action_button("Go", style: :link, intent: :danger) }
    assert_raises(ArgumentError) { action_button("Go", style: :solid, intent: :brand, size: :xl) }
    assert_raises(ArgumentError) { action_button("Go", style: :pill, intent: :brand) }
  end

  test "blank label without aria-label raises" do
    assert_raises(ArgumentError) do
      action_button("", style: :solid, intent: :brand)
    end

    html = action_button("", style: :solid, intent: :brand, aria: { label: "Print" })
    assert_select_html html, "button[aria-label=Print]"
  end

  test "native disabled buttons retain disabled" do
    html = action_button("Wait", style: :outline, intent: :neutral, disabled: true)

    assert_select_html html, "button.btn.btn--outline.btn--neutral.btn--standard[disabled]"
  end

  private

  def assert_select_html(html, selector, text: nil, count: nil)
    doc = Nokogiri::HTML::DocumentFragment.parse(html)
    nodes = doc.css(selector)
    assert_equal(count, nodes.size, "expected #{count} nodes for #{selector}, got #{nodes.size}") unless count.nil?
    assert_predicate nodes, :any?, "expected selector #{selector} in #{html}" if count.nil? || count.positive?
    assert_includes nodes.first.text, text if text
  end
end
