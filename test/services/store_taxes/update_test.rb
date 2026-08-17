# frozen_string_literal: true

require "test_helper"

class StoreTaxes::UpdateTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    @tax = tax_class(code: "physical_book", name: "Physical book")
    @store_tax = StoreTaxes::Create.call(
      store: @store,
      actor: @actor,
      name: "Illinois State",
      rate_percent: "5.000",
      calculation_order: 1,
      applies_by_tax_class_id: { @tax.id => true }
    )
  end

  test "rule-only edits advance the parent lock_version" do
    version = @store_tax.lock_version

    StoreTaxes::Update.call(
      store_tax: @store_tax,
      actor: @actor,
      expected_lock_version: version,
      applies_by_tax_class_id: { @tax.id => false }
    )

    @store_tax.reload
    assert_equal version + 1, @store_tax.lock_version
    assert_equal false, @store_tax.store_tax_rules.find_by!(tax_class: @tax).applies
    event = AuditEvent.where(action: "store_taxes.update").order(:created_at).last
    assert_equal true, event.before_values.fetch("applies").fetch("physical_book")
    assert_equal false, event.after_values.fetch("applies").fetch("physical_book")
  end

  test "stale lock_version rejects a later applies edit" do
    stale = @store_tax.lock_version
    StoreTaxes::Update.call(
      store_tax: @store_tax,
      actor: @actor,
      expected_lock_version: stale,
      applies_by_tax_class_id: { @tax.id => false }
    )

    error = assert_raises(StoreTaxes::Update::Error) do
      StoreTaxes::Update.call(
        store_tax: @store_tax.reload,
        actor: @actor,
        expected_lock_version: stale,
        applies_by_tax_class_id: { @tax.id => true }
      )
    end
    assert_match(/changed by someone else/, error.message)
    assert_equal false, @store_tax.reload.store_tax_rules.find_by!(tax_class: @tax).applies
  end
end
