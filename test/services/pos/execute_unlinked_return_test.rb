# frozen_string_literal: true

require "test_helper"

class PosExecuteUnlinkedReturnTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @admin = @bootstrap[:administrator]
    @tax = tax_class(code: "physical_book", name: "Physical book")
    StoreTaxes::Create.call(
      store: @store,
      actor: @admin,
      name: "Illinois State",
      rate_percent: "5.000",
      calculation_order: 1,
      applies_by_tax_class_id: { @tax.id => true }
    )
    @variant = pos_sellable_variant(actor: @admin, tax_class: @tax)
    open_quantity_stock(store: @store, variant: @variant, actor: @admin, quantity: 20, unit_cost_cents: 100)
    @associate = pos_transacting_user(store: @store, assigned_by: @admin, username: "clerk65c")
    @manager = pos_store_manager(store: @store, assigned_by: @admin, username: "mgr65c")
    Pos::TenderTypes.seed!
  end

  test "associate unlinked return requires a manager and binds fingerprint material" do
    transaction = start_transaction(@associate)
    line = add_unlinked!(
      transaction,
      @associate,
      quantity: 2,
      requested_return_unit_price_cents: 1800,
      reason_code: "defective",
      approver_username: "mgr65c",
      approver_password: "correct-horse-battery"
    )

    action = line.pos_controlled_actions.find_by!(action_type: "unlinked_return")
    assert line.unlinked_return?
    assert_nil line.original_transaction_line_id
    assert_equal 2, line.quantity
    assert_equal 1999, line.reference_unit_price_cents
    assert_equal 1800, line.selling_unit_price_cents
    assert_equal 0, line.manual_discount_cents
    assert_equal "defective", line.return_reason_code
    assert_equal "approval_required", action.policy_result
    assert_equal @associate.id, action.performed_by_user_id
    assert_equal @manager.id, action.approved_by_user_id
    assert_equal(
      {
        "product_variant_id" => @variant.id.to_s,
        "quantity" => 2,
        "reference_unit_price_cents" => 1999,
        "requested_return_unit_price_cents" => 1800,
        "tax_class_id" => @tax.id.to_s
      },
      action.material_values
    )
    assert_equal fingerprint_for(transaction, line, action), action.action_fingerprint
    assert AuditEvent.exists?(action: "pos.unlinked_return.applied", subject_id: line.id)
    assert AuditEvent.exists?(action: "pos.controlled_action.approved", actor_user_id: @manager.id, subject_id: line.id)
  end

  test "manager cashier applies an unlinked return as direct" do
    transaction = start_transaction(@manager)
    line = add_unlinked!(transaction, @manager)

    action = line.pos_controlled_actions.find_by!(action_type: "unlinked_return")
    assert_equal "direct", action.policy_result
    assert_nil action.approved_by_user_id
    refute AuditEvent.exists?(action: "pos.controlled_action.approved", subject_id: line.id)
  end

  test "zero dollar unlinked return still advances lock_version" do
    transaction = start_transaction(@manager)
    before = transaction.lock_version
    line = add_unlinked!(transaction, @manager, requested_return_unit_price_cents: 0)

    assert_equal 0, line.selling_unit_price_cents
    assert_operator transaction.reload.lock_version, :>, before
  end

  test "return price may be above the current reference" do
    transaction = start_transaction(@manager)
    line = add_unlinked!(transaction, @manager, requested_return_unit_price_cents: 2500)

    assert_equal 1999, line.reference_unit_price_cents
    assert_equal 2500, line.selling_unit_price_cents
  end

  test "successful addition clears working tenders" do
    transaction = start_transaction(@manager)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @manager,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku
    )
    transaction.reload
    Pos::TenderCash.call(
      transaction: transaction,
      actor: @manager,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: transaction.total_cents
    )
    assert_equal 1, transaction.reload.pos_tenders.count

    add_unlinked!(transaction.reload, @manager)
    assert_equal 0, transaction.reload.pos_tenders.count
  end

  test "unknown used identifier is rejected" do
    transaction = start_transaction(@manager)
    error = assert_raises(Pos::Error) do
      add_unlinked!(transaction, @manager, identifier: Identifiers::Ean13.complete("220", "999999001"))
    end
    assert_match(/merchandise not found/, error.message)
    assert_equal 0, transaction.reload.pos_transaction_lines.count
  end

  test "on-hand used unit is rejected" do
    _used_variant, unit = pos_on_hand_unit(store: @store, actor: @admin, tax_class: @tax)
    transaction = start_transaction(@manager)
    error = assert_raises(Pos::Error) do
      add_unlinked!(transaction, @manager, identifier: unit.unit_identifier)
    end
    assert_match(/unit must be removed/, error.message)
  end

  test "missing regular price is rejected" do
    @variant.update_columns(regular_price_cents: nil)
    transaction = start_transaction(@manager)
    error = assert_raises(Pos::Error) do
      add_unlinked!(transaction, @manager)
    end
    assert_match(/regular price is required/, error.message)
  end

  test "missing return price is rejected" do
    transaction = start_transaction(@manager)
    error = assert_raises(Pos::Error) do
      add_unlinked!(transaction, @manager, requested_return_unit_price_cents: nil)
    end
    assert_match(/return price must be a non-negative integer/, error.message)
  end

  test "discontinued merchandise with a price is returnable without inheriting sellable" do
    @variant.update!(status: "discontinued")
    @variant.product.update!(status: "discontinued")
    refute @variant.reload.sellable?

    transaction = start_transaction(@manager)
    line = add_unlinked!(transaction, @manager)
    assert_equal @variant.id, line.product_variant_id
  end

  test "product-primary identifier with multiple variants requires selecting a variant" do
    ProductVariants::Create.call(
      product: @variant.product,
      attributes: {
        variant_type: "standard",
        status: "active",
        merchandise_class_id: @variant.merchandise_class_id,
        regular_price_cents: 1500
      },
      actor: @admin
    )
    transaction = start_transaction(@manager)
    error = assert_raises(Pos::Error) do
      add_unlinked!(transaction, @manager, identifier: @variant.product.primary_identifier)
    end
    assert_match(/select a product, variant, or unit/i, error.message)

    line = add_unlinked!(
      transaction.reload,
      @manager,
      identifier: @variant.product.primary_identifier,
      product_variant_id: @variant.id
    )
    assert_equal @variant.id, line.product_variant_id
  end

  test "product industry identifier and unique lookup code reach the same variant" do
    Identifiers::AssignProductIndustry.call(product: @variant.product, raw_value: external_isbn13)
    @variant.product.update!(lookup_code: "UNL-1")

    transaction = start_transaction(@manager)
    by_industry = add_unlinked!(transaction, @manager, identifier: external_isbn13)
    by_lookup_code = add_unlinked!(transaction.reload, @manager, identifier: "unl-1")

    assert_equal @variant.id, by_industry.product_variant_id
    assert_equal @variant.id, by_lookup_code.product_variant_id
  end

  test "a shared lookup code requires selecting a product then resolves" do
    @variant.product.update!(lookup_code: "UNL-SHARED")
    other_product = Products::Create.call(
      attributes: { name: "Other Unlinked", status: "active" },
      actor: @admin,
      lookup_code: "UNL-SHARED"
    )
    ProductVariants::Create.call(
      product: other_product,
      attributes: {
        variant_type: "standard",
        status: "active",
        merchandise_class_id: @variant.merchandise_class_id,
        regular_price_cents: 1500
      },
      actor: @admin
    )

    transaction = start_transaction(@manager)
    error = assert_raises(Pos::Error) do
      add_unlinked!(transaction, @manager, identifier: "unl-shared")
    end
    assert_match(/select a product, variant, or unit/i, error.message)

    line = add_unlinked!(
      transaction.reload,
      @manager,
      identifier: "unl-shared",
      product_id: @variant.product_id
    )
    assert_equal @variant.id, line.product_variant_id
    assert_equal 1, transaction.reload.pos_transaction_lines.count
  end

  test "reject product selection that is not among shared lookup matches" do
    @variant.product.update!(lookup_code: "UNL-BOUND")
    Products::Create.call(
      attributes: { name: "Shared Peer", status: "active" },
      actor: @admin,
      lookup_code: "UNL-BOUND"
    )
    outsider = pos_sellable_variant(actor: @admin, tax_class: @tax, name: "Outsider")

    transaction = start_transaction(@manager)
    error = assert_raises(Pos::InvalidatedDialogBasis) do
      add_unlinked!(
        transaction,
        @manager,
        identifier: "unl-bound",
        product_id: outsider.product_id
      )
    end
    assert_equal Pos::ResolveUnlinkedReturnMerchandise::SELECTION_MISMATCH_MESSAGE, error.message
    assert_equal 0, transaction.reload.pos_transaction_lines.count
  end

  test "reject variant selection that does not belong to the identifier product" do
    other = pos_sellable_variant(actor: @admin, tax_class: @tax, name: "Unrelated Variant")

    transaction = start_transaction(@manager)
    error = assert_raises(Pos::InvalidatedDialogBasis) do
      add_unlinked!(
        transaction,
        @manager,
        identifier: @variant.product.primary_identifier,
        product_variant_id: other.id
      )
    end
    assert_equal Pos::ResolveUnlinkedReturnMerchandise::SELECTION_MISMATCH_MESSAGE, error.message
    assert_equal 0, transaction.reload.pos_transaction_lines.count
  end

  test "reject unit selection unrelated to the scanned variant identifier" do
    _foreign_variant, foreign_unit = pos_on_hand_unit(store: @store, actor: @admin, tax_class: @tax, name: "Foreign Unit")
    foreign_unit.update_columns(lifecycle_state: "removed", removed_at: Time.current)

    transaction = start_transaction(@manager)
    error = assert_raises(Pos::InvalidatedDialogBasis) do
      add_unlinked!(
        transaction,
        @manager,
        identifier: @variant.sku,
        inventory_unit_id: foreign_unit.id
      )
    end
    assert_equal Pos::ResolveUnlinkedReturnMerchandise::SELECTION_MISMATCH_MESSAGE, error.message
    assert_equal 0, transaction.reload.pos_transaction_lines.count
  end

  test "unlinked returns do not merge on rescan" do
    transaction = start_transaction(@manager)
    first = add_unlinked!(transaction, @manager)
    second = add_unlinked!(transaction.reload, @manager)

    assert_equal 2, transaction.reload.pos_transaction_lines.count
    assert_not_equal first.id, second.id
    assert_equal 1, first.quantity
    assert_equal 1, second.quantity
  end

  test "denied approver produces no line and audits the working transaction" do
    transaction = start_transaction(@associate)
    error = assert_raises(Pos::Error) do
      add_unlinked!(
        transaction,
        @associate,
        approver_username: "mgr65c",
        approver_password: "wrong-password"
      )
    end
    assert_match(/approver credentials are invalid/, error.message)
    assert_equal 0, transaction.reload.pos_transaction_lines.count
    assert_equal 0, PosControlledAction.where(pos_transaction_id: transaction.id).count

    event = AuditEvent.find_by!(action: "pos.controlled_action.denied")
    assert_equal "denied", event.outcome
    assert_equal transaction.id, event.subject_id
    assert_equal "PosTransaction", event.subject_type
  end

  test "stale preview expectations reject without creating a line" do
    transaction = start_transaction(@manager)
    error = assert_raises(Pos::InvalidatedDialogBasis) do
      add_unlinked!(transaction, @manager, expected_reference_unit_price_cents: 1)
    end
    assert_equal Pos::ExecuteUnlinkedReturn::STALE_PREVIEW_MESSAGE, error.message
    assert_equal 0, transaction.reload.pos_transaction_lines.count
  end

  private

  def start_transaction(actor)
    context = pos_open_context(store: @store, actor: actor)
    Pos::StartTransaction.call(session: context[:session], actor: actor)
  end

  def add_unlinked!(transaction, actor, **attrs)
    identifier = attrs.delete(:identifier) || @variant.sku
    Pos::ExecuteUnlinkedReturn.call(
      transaction: transaction,
      actor: actor,
      expected_lock_version: transaction.lock_version,
      identifier: identifier,
      quantity: attrs.fetch(:quantity, 1),
      reason_code: attrs.fetch(:reason_code, "changed_mind"),
      reason_note: attrs[:reason_note],
      requested_return_unit_price_cents: attrs.fetch(:requested_return_unit_price_cents, 1999),
      approver_username: attrs[:approver_username],
      approver_password: attrs[:approver_password],
      expected_product_variant_id: attrs[:expected_product_variant_id],
      expected_inventory_unit_id: attrs[:expected_inventory_unit_id],
      expected_reference_unit_price_cents: attrs[:expected_reference_unit_price_cents],
      expected_tax_class_id: attrs[:expected_tax_class_id],
      product_id: attrs[:product_id],
      product_variant_id: attrs[:product_variant_id],
      inventory_unit_id: attrs[:inventory_unit_id]
    )
  end

  def fingerprint_for(transaction, line, action)
    Pos::ControlledActionFingerprint.call(
      action_type: "unlinked_return",
      transaction_id: transaction.id,
      line_id: line.id,
      material_values: action.material_values,
      reason_code: action.reason_code,
      reason_note: action.reason_note
    )
  end
end
