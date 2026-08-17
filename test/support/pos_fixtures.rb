# frozen_string_literal: true

module PosFixtures
  def pos_sellable_variant(actor:, tax_class:, pricing_method: "fixed", variant_type: "standard")
    department = department(code: "pos_#{SecureRandom.hex(3)}", default_tax_class: tax_class)
    klass = merchandise_class(
      code: "pos_#{SecureRandom.hex(3)}",
      default_standard_department: department,
      pricing_method: pricing_method,
      used_merchandise_allowed: variant_type == "used",
      inventory_mode: "inventory"
    )
    product = Products::Create.call(
      attributes: { name: "Example Book", status: "active" },
      actor: actor,
      identifier_mode: "generate"
    )
    ProductVariants::Create.call(
      product: product,
      attributes: {
        variant_type: variant_type,
        status: "active",
        merchandise_class_id: klass.id,
        department_id: department.id,
        tax_class_id: tax_class.id,
        regular_price_cents: pricing_method == "open_price" ? nil : 1999
      }.compact,
      actor: actor
    )
  end

  def pos_open_context(store:, actor:, register: nil)
    register ||= Register.create!(store: store, register_number: format("%02d", store.registers.count + 1), name: "Front")
    period = Pos::OpenReportingPeriod.call(store: store, register: register, actor: actor)
    session = Pos::OpenSession.call(store: store, register: register, actor: actor, reporting_period: period)
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
end
