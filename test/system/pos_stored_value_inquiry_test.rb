# frozen_string_literal: true

require "application_system_test_case"

class PosStoredValueInquirySystemTest < ApplicationSystemTestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    GiftCards::Programs.seed!
    @program = GiftCardProgram.find_by!(code: "generated")
    @register = Register.create!(store: @store, register_number: 41, name: "Inquiry")
  end

  test "customer match results focus the result panel and stay visible at high zoom" do
    Customer.create!(
      display_name: "Focus Inquiry Customer",
      email: "focus.inquiry@example.com",
      phone: "555-0141"
    )

    sign_in_admin(actor: @actor)
    visit pos_stored_value_inquiry_path(register_id: @register.id)
    assert_text "Stored Value Inquiry"

    fill_in "Customer", with: "Focus Inquiry Customer"
    click_on "Find store credit"

    assert_selector "#sv-inquiry-result", text: /Matching customers/
    assert_selector "#sv-inquiry-result input[type=submit][value*='Focus Inquiry Customer']"
    assert_equal "sv-inquiry-result", page.evaluate_script("document.activeElement && document.activeElement.id")
    refute_equal "card_number", page.evaluate_script("document.activeElement && document.activeElement.id")

    with_viewport(width: 1280, height: 720, zoom: 2) do
      result = find("#sv-inquiry-result")
      assert result.visible?
      rect = page.evaluate_script(<<~JS)
        (() => {
          const el = document.getElementById("sv-inquiry-result");
          const r = el.getBoundingClientRect();
          return { top: r.top, bottom: r.bottom, height: window.innerHeight };
        })()
      JS
      assert_operator rect["top"], :<, rect["height"], "result panel should remain in the viewport"
      assert_operator rect["bottom"], :>, 0
    end
  end

  test "masked admin results focus the result panel not the exact-card field" do
    card = numbered_card(last_four: "5151")
    GiftCards::Fund.call(gift_card: card, amount_cents: 250, store: @store, performed_by: @actor)

    sign_in_admin(actor: @actor)
    visit pos_stored_value_inquiry_path(register_id: @register.id)
    assert_text "Stored Value Inquiry"

    fill_in "Prefix", with: card.number_prefix
    fill_in "Last four", with: "5151"
    click_on "Find masked history"

    assert_selector "#sv-inquiry-result", text: card.masked_number
    assert_equal "sv-inquiry-result", page.evaluate_script("document.activeElement && document.activeElement.id")
    refute_equal "card_number", page.evaluate_script("document.activeElement && document.activeElement.id")
  end

  private

  def numbered_card(last_four:)
    prefix = @program.prefix
    body_length = @program.number_length - prefix.length - 1
    50_000.times do |index|
      body = format("%0#{body_length}d", index)
      number = "#{prefix}#{body}#{GiftCards::Luhn.check_digit("#{prefix}#{body}")}"
      next unless number.end_with?(last_four)
      next if GiftCard.exists?(number_digest: GiftCards::Number.digest(number))

      return GiftCards::ProvisionInstrument.call(program: @program, store: @store, number: number)
    end
    raise "unable to allocate a #{prefix} number ending in #{last_four}"
  end
end
