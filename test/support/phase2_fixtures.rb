# frozen_string_literal: true

module Phase2Fixtures
  module_function

  BOOTSTRAP_ATTRS = {
    organization_name: "Example Books",
    store_number: 1,
    store_code: "main",
    store_name: "Main Store",
    store_legal_name: "Example Books LLC",
    store_timezone: "America/New_York",
    store_country_code: "US",
    admin_username: "admin",
    admin_display_name: "Admin User",
    admin_password: "correct-horse-battery"
  }.freeze

  def bootstrap!(**overrides)
    Installation::Bootstrap.call(**BOOTSTRAP_ATTRS, **overrides)
  end

  def actor_user(bootstrap: nil)
    bootstrap ||= bootstrap!
    bootstrap[:administrator]
  end

  def external_isbn13
    Identifiers::Ean13.complete("978", "123456789")
  end

  def shelfsense_222(payload9 = "000000001")
    Identifiers::Ean13.complete("222", payload9)
  end

  def shelfsense_221(payload9 = "000000001")
    Identifiers::Ean13.complete("221", payload9)
  end

  def tax_class(code: "taxable", name: nil, active: true, **attrs)
    TaxClass.create!(
      {
        code: code,
        name: name || code.to_s.tr("_", " ").capitalize,
        active: active,
        display_order: 0
      }.merge(attrs)
    )
  end

  def gl_account(account_number:, account_type:, account_category:, posting_allowed: true, active: true, name: nil, **attrs)
    GlAccount.create!(
      {
        account_number: account_number,
        name: name || "Account #{account_number}",
        account_type: account_type,
        account_category: account_category,
        posting_allowed: posting_allowed,
        active: active,
        display_order: 0
      }.merge(attrs)
    )
  end

  def department(code:, name: nil, active: true, department_number: nil, **gl_mappings)
    Department.create!(
      {
        code: code,
        name: name || code.to_s.tr("_", " ").capitalize,
        department_number: department_number || code.to_s.upcase,
        active: active,
        display_order: 0
      }.merge(gl_mappings)
    )
  end

  def merchandise_class(
    code:,
    department: nil,
    default_tax_class: nil,
    pricing_method: "fixed",
    used_merchandise_allowed: false,
    inventory_mode: "inventory",
    merchandise_class_number: nil,
    name: nil,
    active: true,
    **attrs
  )
    department ||= self.department(code: "#{code}_dept")
    default_tax_class ||= tax_class(code: "#{code}_tax")
    MerchandiseClass.create!(
      {
        code: code,
        name: name || code.to_s.tr("_", " ").capitalize,
        department: department,
        merchandise_class_number: merchandise_class_number || code.to_s.upcase[0, 20],
        default_tax_class: default_tax_class,
        default_pricing_method: pricing_method,
        default_inventory_mode: inventory_mode,
        used_merchandise_allowed: used_merchandise_allowed,
        active: active,
        display_order: 0
      }.merge(attrs)
    )
  end

  def merchandise_category(
    name:,
    default_standard_merchandise_class: nil,
    default_used_merchandise_class: nil,
    default_merchandise_class: nil,
    code: nil,
    parent: nil,
    active: true,
    **attrs
  )
    standard = default_standard_merchandise_class || default_merchandise_class
    MerchandiseCategory.create!(
      {
        name: name,
        code: code,
        default_standard_merchandise_class: standard,
        default_used_merchandise_class: default_used_merchandise_class,
        parent: parent,
        active: active,
        display_order: 0
      }.merge(attrs)
    )
  end

  def merchandise_condition(
    code:,
    price_adjustment_bps: 10_000,
    name: nil,
    active: true,
    **attrs
  )
    MerchandiseCondition.create!(
      {
        code: code,
        name: name || code.to_s.tr("_", " ").capitalize,
        price_adjustment_bps: price_adjustment_bps,
        active: active,
        display_order: 0
      }.merge(attrs)
    )
  end

  def inventory_gl(account_number: "1200")
    gl_account(account_number: account_number, account_type: "asset", account_category: "inventory")
  end

  def cogs_gl(account_number: "5000")
    gl_account(account_number: account_number, account_type: "expense", account_category: "cost_of_goods_sold")
  end

  def sales_gl(account_number: "4000")
    gl_account(account_number: account_number, account_type: "revenue", account_category: "sales")
  end
end
