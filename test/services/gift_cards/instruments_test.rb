# frozen_string_literal: true

require "test_helper"

module GiftCards
  class InstrumentsTest < ActiveSupport::TestCase
    setup do
      @bootstrap = bootstrap!
      @store = @bootstrap[:store]
      @actor = @bootstrap[:administrator]
      GiftCards::Programs.seed!
      @program = GiftCardProgram.find_by!(code: "generated")
      @manual = GiftCardProgram.find_by!(code: "manual")
    end

    test "seeded programs use non-overlapping prefixes and do not collide with merchandise length" do
      assert_equal "801", @program.prefix
      assert_equal "802", @manual.prefix
      assert_not_equal @program.prefix, @manual.prefix
      assert_equal 20, @program.number_length
      assert @program.system_generated?
      assert @manual.manual_external?
    end

    test "stores numbers with encryption and lookup by hmac digest" do
      number = GiftCards::Number.generate(@program)
      card = GiftCards::ProvisionInstrument.call(program: @program, store: @store, number: number)
      GiftCards::Fund.call(gift_card: card, amount_cents: 250, store: @store, performed_by: @actor)

      raw = GiftCard.connection.select_value(
        GiftCard.sanitize_sql_array([ "SELECT number FROM gift_cards WHERE id = ?", card.id ])
      )
      assert_equal number, card.number
      assert_equal GiftCards::Number.digest(number), card.number_digest
      assert_not_equal number, raw
      assert_equal number[-4, 4], card.number_last_four
      assert_nil GiftCard.column_names.find { |name| name == "encryption_key_id" }
      assert_not Permission.exists?(key: "gift_cards.reveal_number")

      found = GiftCards::Resolver.call(raw_number: number, actor: @actor, store: @store)
      assert_equal card.id, found.id
    end

    test "inquiry failure is generic and does not persist the submitted number" do
      error = assert_raises(GiftCards::Error) do
        GiftCards::Resolver.call(raw_number: "80100000000000000000", actor: @actor, store: @store)
      end
      assert_equal GiftCards::GENERIC_INQUIRY_FAILURE, error.message
      event = AuditEvent.where(action: "gift_cards.inquiry", outcome: "failed").order(:created_at).last
      assert event
      refute_includes event.attributes.to_json, "80100000000000000000"
    end

    test "number identity cannot be rewritten after issue" do
      card = GiftCards::ProvisionInstrument.call(program: @program, store: @store)
      original = card.number
      other = GiftCards::Number.generate(@program)

      error = assert_raises(ActiveRecord::RecordInvalid) { card.update!(number: other) }
      assert_match(/cannot change after issue/, error.message)
      assert_equal original, card.reload.number

      GiftCards::Suspend.call(gift_card: card, actor: @actor, store: @store)
      assert card.reload.suspended?
    end

    test "suspend and reinstate keep the ledger account in sync" do
      card = GiftCards::ProvisionInstrument.call(program: @program, store: @store)
      GiftCards::Suspend.call(gift_card: card, actor: @actor, store: @store)
      assert card.reload.suspended?
      assert card.stored_value_account.reload.suspended?

      GiftCards::Reinstate.call(gift_card: card, actor: @actor, store: @store)
      assert card.reload.active?
      assert card.stored_value_account.reload.active?
    end

    test "replacement moves remaining balance and does not rewrite ledger customer ownership" do
      customer = Customer.create!(display_name: "Card Holder", email: "card.holder@example.com")
      card = GiftCards::ProvisionInstrument.call(program: @program, store: @store, customer: customer)
      GiftCards::Fund.call(gift_card: card, amount_cents: 700, store: @store, performed_by: @actor)

      replacement = GiftCards::Replace.call(
        gift_card: card,
        performed_by: @actor,
        store: @store,
        source_id: card.id,
        idempotency_key: SecureRandom.uuid_v7,
        reason_code: "lost",
        reason_name_snapshot: "Lost card"
      )

      assert card.reload.replaced?
      assert_equal 0, card.stored_value_account.reload.balance_cents
      assert card.stored_value_account.closed?
      new_card = replacement.replacement_gift_card
      assert_equal 700, new_card.stored_value_account.reload.balance_cents
      assert_equal customer.id, new_card.customer_id
      assert_nil new_card.stored_value_account.customer_id
      assert OutboxMessage.exists?(event_type: "gift_card.replaced")
      assert_not_includes AuditEvent.order(:created_at).last.after_values.to_s, new_card.number
    end

    test "merge reassigns gift-card customer association without transferring instrument value" do
      source = Customer.create!(display_name: "Source Card", email: "src.card@example.com")
      survivor = Customer.create!(display_name: "Survivor Card", email: "surv.card@example.com")
      card = GiftCards::ProvisionInstrument.call(program: @program, store: @store, customer: source)
      GiftCards::Fund.call(gift_card: card, amount_cents: 300, store: @store, performed_by: @actor)

      Customers::MergeCustomers.call(
        source: source,
        survivor: survivor,
        actor: @actor,
        reason: "same person",
        idempotency_key: SecureRandom.uuid_v7,
        store: @store
      )

      assert_equal survivor.id, card.reload.customer_id
      assert_equal 300, card.stored_value_account.reload.balance_cents
      assert_nil StoredValueAccount.find_by(customer: survivor, account_type: "gift_card")
    end
  end
end
