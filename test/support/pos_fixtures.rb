# frozen_string_literal: true

module PosFixtures
  def pos_sellable_variant(
    actor:,
    tax_class:,
    pricing_method: "fixed",
    variant_type: "standard",
    inventory_mode: "inventory",
    name: "Example Book"
  )
    department = department(code: "pos_#{SecureRandom.hex(3)}", default_tax_class: tax_class)
    klass = merchandise_class(
      code: "pos_#{SecureRandom.hex(3)}",
      default_standard_department: department,
      default_used_department: variant_type == "used" ? department : nil,
      pricing_method: pricing_method,
      used_merchandise_allowed: variant_type == "used",
      inventory_mode: inventory_mode
    )
    product = Products::Create.call(
      attributes: { name: name, status: "active" },
      actor: actor,
      identifier_mode: "generate"
    )
    attributes = {
      variant_type: variant_type,
      status: "active",
      merchandise_class_id: klass.id,
      department_id: department.id,
      tax_class_id: tax_class.id,
      regular_price_cents: pricing_method == "open_price" ? nil : 1999
    }
    if variant_type == "used"
      attributes[:merchandise_condition_id] = merchandise_condition(code: "pos_#{SecureRandom.hex(3)}").id
      attributes[:regular_price_cents] = 1200 unless pricing_method == "open_price"
    end
    ProductVariants::Create.call(
      product: product,
      attributes: attributes.compact,
      actor: actor
    )
  end

  def pos_on_hand_unit(store:, actor:, tax_class:, unit_cost_cents: 500, regular_price_cents: 1200, name: "Used Book")
    variant = pos_sellable_variant(
      actor: actor,
      tax_class: tax_class,
      variant_type: "used",
      name: name
    )
    Inventory::AdjustmentReasons.seed!
    acquisition = Inventory::PostAdjustment.call(
      store: store,
      product_variant: variant,
      adjustment_reason: AdjustmentReason.find_by!(code: "opening_inventory"),
      quantity_delta: 1,
      actor: actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      acquisition_unit_cost_cents: unit_cost_cents,
      regular_price_cents: regular_price_cents
    )
    [ variant, acquisition.inventory_unit ]
  end

  def pos_open_context(store:, actor:, register: nil, opening_float_cents: 0)
    register ||= Register.create!(store: store, register_number: (store.registers.maximum(:register_number) || 0) + 1, name: "Front")
    period = Pos::OpenReportingPeriod.call(store: store, register: register, actor: actor)
    session = Pos::OpenSession.call(
      store: store,
      register: register,
      actor: actor,
      reporting_period: period,
      opening_float_cents: opening_float_cents
    )
    { register: register, period: period, session: session }
  end

  def open_quantity_stock(store:, variant:, actor:, quantity:, unit_cost_cents: 100)
    Inventory::AdjustmentReasons.seed!
    Inventory::PostAdjustment.call(
      store: store,
      product_variant: variant,
      adjustment_reason: AdjustmentReason.find_by!(code: "opening_inventory"),
      quantity_delta: quantity,
      actor: actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      acquisition_unit_cost_cents: unit_cost_cents
    )
  end

  def pos_transacting_user(store:, assigned_by:, username:)
    user = User.create!(
      username: username,
      display_name: username,
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    RoleAssignment.create!(
      user: user,
      role: Role.find_by!(key: "associate"),
      store: store,
      assigned_by: assigned_by,
      effective_at: Time.current
    )
    user
  end

  def pos_store_manager(store:, assigned_by:, username:)
    user = User.create!(
      username: username,
      display_name: username,
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    RoleAssignment.create!(
      user: user,
      role: Role.find_by!(key: "store_manager"),
      store: store,
      assigned_by: assigned_by,
      effective_at: Time.current
    )
    user
  end

  def insert_completed_transaction!(
    session:,
    receipt_sequence:,
    completed_at:,
    business_date: nil,
    cashier_name: "Jane Smith",
    cashier_user: nil,
    total_cents: 2099
  )
    store = session.store
    register = session.register
    business_date ||= session.reporting_period.business_date
    PosTransaction.create!(
      store: store,
      register: register,
      pos_session: session,
      reporting_period: session.reporting_period,
      cashier_user: cashier_user || session.cashier_user,
      cashier_name_snapshot: cashier_name,
      status: "completed",
      currency_code: "USD",
      occurred_at: completed_at,
      completed_at: completed_at,
      business_date: business_date,
      receipt_sequence: receipt_sequence,
      store_number_snapshot: store.store_number,
      register_number_snapshot: register.register_number,
      transaction_reference: Pos::ReceiptIdentity.reference(
        store_number: store.store_number,
        register_number: register.register_number,
        receipt_sequence: receipt_sequence
      ),
      subtotal_cents: total_cents,
      tax_cents: 0,
      total_cents: total_cents,
      signed_net_cents: total_cents
    )
  end
end
