# frozen_string_literal: true

module UdsReviewDialogContract
  def assert_review_dialog_contract(trigger_label:, submit_label: nil, initial_focus_name: nil)
    trigger = find(:button, trigger_label, match: :first)
    trigger.click

    assert_selector "dialog[open]", wait: 5
    if initial_focus_name.present?
      assert_equal initial_focus_name, page.evaluate_script("document.activeElement && document.activeElement.name")
    end

    tabbables_before = page.evaluate_script(<<~JS)
    Array.from(document.querySelector("dialog[open]").querySelectorAll(
      "a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex='-1'])"
    )).length
  JS
    assert tabbables_before.positive?, "review dialog has no tabbable controls"

    send_keys :tab
    assert_selector "dialog[open]"

    send_keys :escape
    assert_no_selector "dialog[open]", wait: 5
    assert page.evaluate_script(<<~JS), "focus did not return to review trigger"
      document.activeElement === document.querySelector("[data-review-dialog-target='trigger']")
    JS

    return unless submit_label

    find(:button, trigger_label, match: :first).click
    assert_selector "dialog[open]", wait: 5
    click_on submit_label
  end
end
