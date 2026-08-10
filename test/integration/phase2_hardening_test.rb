# frozen_string_literal: true

require "test_helper"

class Phase2HardeningTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @actor = @bootstrap[:administrator]
    sign_in_as("admin")
    @tax = tax_class(code: "books")
    @dept = department(code: "new_books", default_tax_class: @tax)
    @klass = merchandise_class(code: "book", pricing_method: "fixed", default_standard_department: @dept)
    @condition = merchandise_condition(code: "new")
  end

  test "cross-namespace uniqueness blocks product primary equal to variant sku" do
    product = Products::Create.call(
      attributes: { name: "Owner", status: "draft" },
      actor: @actor,
      identifier_mode: "generate"
    )
    variant = ProductVariants::Create.call(
      product: product,
      actor: @actor,
      attributes: { merchandise_condition_id: @condition.id }
    )

    error = assert_raises(Products::Create::Error) do
      Products::Create.call(
        attributes: { name: "Collision", status: "draft" },
        actor: @actor,
        identifier_mode: "enter",
        external_identifier: variant.sku
      )
    end
    assert_match(/already reserved/i, error.message)
  end

  test "draft product delete leaves a retired registry tombstone" do
    product = Products::Create.call(
      attributes: { name: "Draft delete", status: "draft" },
      actor: @actor,
      identifier_mode: "generate"
    )
    value = product.primary_identifier

    delete admin_product_path(product)
    assert_redirected_to admin_products_path
    assert_nil Product.find_by(id: product.id)

    row = Identifiers::Registry.find_any(value)
    assert row.present?
    assert row.retired_at.present?
    assert_nil row.product_id
  end

  test "retired identifiers cannot be reallocated" do
    product = Products::Create.call(
      attributes: { name: "Retire", status: "draft" },
      actor: @actor,
      identifier_mode: "generate"
    )
    value = product.primary_identifier
    delete admin_product_path(product)

    error = assert_raises(Identifiers::Registry::ConflictError) do
      Identifiers::Registry.reserve!(
        value: value,
        kind: "product_primary",
        product: Products::Create.call(
          attributes: { name: "Other", status: "draft" },
          actor: @actor,
          identifier_mode: "enter",
          external_identifier: external_isbn13
        )
      )
    end
    assert_match(/already reserved/i, error.message)

    error = assert_raises(Products::Create::Error) do
      Products::Create.call(
        attributes: { name: "Reuse 222", status: "draft" },
        actor: @actor,
        identifier_mode: "enter",
        external_identifier: value
      )
    end
    assert_match(/reserved 222|already reserved/i, error.message)
  end

  test "sequence exhaustion raises Generator::ExhaustedError" do
    connection = ActiveRecord::Base.connection
    original_select = connection.method(:select_value)

    connection.define_singleton_method(:select_value) do |sql|
      if sql.to_s.include?("nextval") && sql.to_s.include?("shelfsense_product_222_seq")
        raise ActiveRecord::StatementInvalid, "PG::SequenceError: nextval: reached maximum value of sequence \"shelfsense_product_222_seq\" (MAXVALUE)"
      end

      original_select.call(sql)
    end

    begin
      assert_raises(Identifiers::Generator::ExhaustedError) do
        Identifiers::Generator.next_ean13!("222")
      end
    ensure
      connection.define_singleton_method(:select_value) do |sql|
        original_select.call(sql)
      end
    end
  end

  test "inactive reference is rejected on new assignment" do
    inactive_tax = tax_class(code: "inactive_tax", active: false)
    inactive_class = merchandise_class(code: "inactive_class", active: false, default_standard_department: @dept)
    inactive_condition = merchandise_condition(code: "inactive_cond", active: false)
    inactive_dept = department(code: "inactive_dept", default_tax_class: @tax, active: false)

    product = Products::Create.call(
      attributes: { name: "Refs", status: "draft" },
      actor: @actor,
      identifier_mode: "generate"
    )

    assert_raises(ProductVariants::Create::Error) do
      ProductVariants::Create.call(
        product: product,
        actor: @actor,
        attributes: { merchandise_condition_id: inactive_condition.id }
      )
    end

    variant = ProductVariants::Create.call(
      product: product,
      actor: @actor,
      attributes: { merchandise_condition_id: @condition.id }
    )

    variant.merchandise_class = inactive_class
    assert_not variant.valid?
    assert_includes variant.errors[:merchandise_class_id], "must be an active merchandise class"

    variant.reload
    variant.department = inactive_dept
    assert_not variant.valid?
    assert_includes variant.errors[:department_id], "must be an active department"

    variant.reload
    variant.tax_class = inactive_tax
    assert_not variant.valid?
    assert_includes variant.errors[:tax_class_id], "must be an active tax class"
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
    follow_redirect! if response.redirect?
  end
end
