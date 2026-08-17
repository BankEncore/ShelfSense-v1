# frozen_string_literal: true

require "test_helper"

class StoreTaxes::AuthorizationTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    @tax = tax_class(code: "physical_book", name: "Physical book")
    @associate = pos_transacting_user(store: @store, assigned_by: @actor, username: "tax_clerk")
  end

  test "unauthorized create is denied and audited" do
    assert_raises(StoreTaxes::Denied) do
      StoreTaxes::Create.call(
        store: @store,
        actor: @associate,
        name: "Denied tax",
        rate_percent: "1.000",
        calculation_order: 0
      )
    end
    assert_not StoreTax.exists?(name: "Denied tax")
    event = AuditEvent.where(action: "authorization.denied").order(:created_at).last
    assert_equal "denied", event.outcome
    assert_equal "store_taxes.create", event.reason_code
  end

  test "unauthorized update is denied and audited" do
    store_tax = StoreTaxes::Create.call(
      store: @store,
      actor: @actor,
      name: "Illinois State",
      rate_percent: "5.000",
      calculation_order: 1,
      applies_by_tax_class_id: { @tax.id => true }
    )

    assert_raises(StoreTaxes::Denied) do
      StoreTaxes::Update.call(
        store_tax: store_tax,
        actor: @associate,
        expected_lock_version: store_tax.lock_version,
        name: "Hijacked"
      )
    end
    assert_equal "Illinois State", store_tax.reload.name
    event = AuditEvent.where(action: "authorization.denied").order(:created_at).last
    assert_equal "denied", event.outcome
    assert_equal "store_taxes.update", event.reason_code
  end
end
