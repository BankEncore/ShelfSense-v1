# frozen_string_literal: true

require "test_helper"

class PosTenderReviewMutationsTest < ActiveSupport::TestCase
  setup do
    bootstrap = bootstrap!
    @store = bootstrap[:store]
    @actor = bootstrap[:administrator]
    tax = tax_class(code: "tender_review", name: "Tender review")
    variant = pos_sellable_variant(actor: @actor, tax_class: tax)
    open_quantity_stock(store: @store, variant: variant, actor: @actor, quantity: 20)
    @variant = variant
    @context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 10_000)
    Pos::TenderTypes.seed!
    @cash = TenderType.find_by!(code: "cash")
    @card = TenderType.find_by!(code: "card")
    @check = TenderType.find_by!(code: "check")
  end

  test "ordinary remove completes a replayable lease and payload mismatch is rejected" do
    transaction = start_sale
    tender = add_tender(transaction, @card, 500, "AUTH-1")
    operation_id = SecureRandom.uuid_v7
    lock_version = transaction.reload.lock_version

    first = Pos::RemoveWorkingTender.call(
      transaction: transaction,
      tender: tender,
      actor: @actor,
      operation_id: operation_id,
      expected_lock_version: lock_version
    )
    assert_not first.replayed
    assert_equal "completed", first.operation.status
    assert_equal PosOperation::REMOVE_WORKING_TENDER_FACT_TYPE, first.operation.fact_type
    assert_not transaction.reload.pos_tenders.exists?(tender.id)

    replay = Pos::RemoveWorkingTender.call(
      transaction: transaction,
      tender: tender,
      actor: @actor,
      operation_id: operation_id,
      expected_lock_version: lock_version
    )
    assert replay.replayed

    assert_raises(Pos::PayloadMismatch) do
      Pos::RemoveWorkingTender.call(
        transaction: transaction,
        tender: tender,
        actor: @actor,
        operation_id: operation_id,
        expected_lock_version: lock_version + 1
      )
    end
  end

  test "remove accepts stored value and replays without restoring ledger value" do
    transaction = start_sale
    tender = add_raw_tender(transaction, TenderType.find_by!(code: "gift_card"), 500)
    operation_id = SecureRandom.uuid_v7
    lock_version = transaction.reload.lock_version
    attrs = {
      transaction: transaction,
      tender: tender,
      actor: @actor,
      operation_id: operation_id,
      expected_lock_version: lock_version
    }

    first = Pos::RemoveWorkingTender.call(**attrs)
    assert_not first.replayed
    assert_not transaction.reload.pos_tenders.exists?(tender.id)
    assert Pos::RemoveWorkingTender.call(**attrs).replayed
    assert_equal 0, StoredValueOperation.count
    event = AuditEvent.where(action: "pos.working_tender.removed").order(:created_at).last
    assert_equal false, event.metadata["stored_value_ledger_affected"]
  end

  test "replace supports cash check and manual-reference other" do
    other = TenderType.create!(
      code: "campus_account",
      name: "Campus Account",
      behavioral_category: "other",
      external_reference_policy: "required",
      active: true
    )

    [
      [ @cash, nil, nil, nil ],
      [ @check, "CHECK-2", 600, nil ],
      [ other, "PO-2", 600, nil ]
    ].each do |type, reference, amount, presented|
      transaction = start_sale
      original =
        if type.cash?
          Pos::TenderCash.call(
            transaction: transaction,
            actor: @actor,
            expected_lock_version: transaction.lock_version,
            amount_presented_cents: transaction.signed_net_cents
          )
        else
          add_tender(transaction, type, 500, type.reference_required? ? "OLD" : nil)
        end
      transaction.reload
      if type.cash?
        amount = original.amount_cents
        presented = amount + 100
      end

      result = Pos::ReplaceTender.call(
        transaction: transaction,
        tender: original,
        actor: @actor,
        operation_id: SecureRandom.uuid_v7,
        expected_lock_version: transaction.lock_version,
        amount_cents: amount,
        amount_presented_cents: presented,
        external_reference: reference
      )
      replacement = result.tender.reload
      assert_equal amount, replacement.amount_cents
      assert_equal reference, replacement.external_reference unless type.cash?
      assert_equal presented - amount, replacement.change_cents if type.cash?
      assert_not_equal original.id, replacement.id
      Pos::CancelTransaction.call(
        transaction: transaction.reload,
        actor: @actor,
        expected_lock_version: transaction.lock_version
      )
    end
  end

  test "replace refuses card tenders without changing the original" do
    transaction = start_sale
    original = add_tender(transaction, @card, 500, "AUTH-KEEP")
    transaction.reload

    error = assert_raises(Pos::Error) do
      Pos::ReplaceTender.call(
        transaction: transaction,
        tender: original,
        actor: @actor,
        operation_id: SecureRandom.uuid_v7,
        expected_lock_version: transaction.lock_version,
        amount_cents: 400,
        external_reference: "AUTH-FORGED"
      )
    end
    assert_match(/re-authorized externally/, error.message)
    assert_equal "AUTH-KEEP", original.reload.external_reference
    assert_equal 500, original.amount_cents
    assert_equal 1, transaction.reload.pos_tenders.count
  end

  test "replace failure preserves the original and successful retry replays replacement" do
    required = TenderType.create!(
      code: "required_reference",
      name: "Required Reference",
      behavioral_category: "other",
      external_reference_policy: "required",
      active: true
    )
    transaction = start_sale
    original = add_tender(transaction, required, 500, "ORIGINAL")
    transaction.reload

    assert_raises(Pos::Error) do
      Pos::ReplaceTender.call(
        transaction: transaction,
        tender: original,
        actor: @actor,
        operation_id: SecureRandom.uuid_v7,
        expected_lock_version: transaction.lock_version,
        amount_cents: 600
      )
    end
    assert_equal "ORIGINAL", original.reload.external_reference

    operation_id = SecureRandom.uuid_v7
    lock_version = transaction.reload.lock_version
    attrs = {
      transaction: transaction,
      tender: original,
      actor: @actor,
      operation_id: operation_id,
      expected_lock_version: lock_version,
      amount_cents: 600,
      external_reference: "REPLACED"
    }
    first = Pos::ReplaceTender.call(**attrs)
    replay = Pos::ReplaceTender.call(**attrs)
    assert replay.replayed
    assert_equal first.tender.id, replay.tender.id
  end

  test "return to sale clears ordinary tenders atomically and replays" do
    transaction = start_sale
    add_tender(transaction, @card, 500, "AUTH")
    operation_id = SecureRandom.uuid_v7
    lock_version = transaction.reload.lock_version
    attrs = {
      transaction: transaction,
      actor: @actor,
      operation_id: operation_id,
      expected_lock_version: lock_version
    }

    first = Pos::ReturnToSaleClearTenders.call(**attrs)
    assert_empty transaction.reload.pos_tenders
    assert_equal PosOperation::RETURN_TO_SALE_CLEAR_TENDERS_FACT_TYPE, first.operation.fact_type
    assert Pos::ReturnToSaleClearTenders.call(**attrs).replayed
  end

  test "return to sale clears ordinary and stored-value tenders together" do
    transaction = start_sale
    add_tender(transaction, @card, 500, "AUTH")
    add_raw_tender(transaction, TenderType.find_by!(code: "gift_card"), 400)
    transaction.reload
    attrs = {
      transaction: transaction,
      actor: @actor,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: transaction.lock_version
    }

    result = Pos::ReturnToSaleClearTenders.call(**attrs)
    assert_empty transaction.reload.pos_tenders
    assert_equal 2, result.operation.envelope.dig("facts", "removed_tender_ids").size
    assert_equal 0, StoredValueOperation.count
    assert Pos::ReturnToSaleClearTenders.call(**attrs).replayed
  end

  private

  def start_sale
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku
    )
    transaction.reload
  end

  def add_tender(transaction, type, amount, reference = nil)
    Pos::AddTender.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      tender_type: type,
      amount_cents: amount,
      external_reference: reference
    )
  end

  def add_raw_tender(transaction, type, amount)
    tender = transaction.pos_tenders.new(
      direction: "payment",
      tender_number: Pos::Support.next_tender_number(transaction),
      amount_cents: amount
    )
    Pos::Support.snapshot_tender_identity!(tender, type)
    tender.save!
    tender
  end
end
