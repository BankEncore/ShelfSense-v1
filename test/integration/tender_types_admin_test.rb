# frozen_string_literal: true

require "test_helper"

class TenderTypesAdminTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @cash = TenderType.find_by!(code: "cash")
  end

  test "admin can create an Other identity and cannot recategorize Cash" do
    sign_in_as("admin")

    post admin_tender_types_path, params: {
      tender_type: {
        code: "campus_charge",
        name: "Campus Charge",
        behavioral_category: "cash",
        external_reference_policy: "required"
      }
    }
    other = TenderType.find_by!(code: "campus_charge")
    assert_redirected_to admin_tender_type_path(other)
    assert_equal "other", other.behavioral_category
    assert_not other.system_protected?
    assert AuditEvent.exists?(action: "tender_types.create", subject_id: other.id)

    patch admin_tender_type_path(@cash), params: {
      tender_type: {
        name: "Cash drawer",
        behavioral_category: "other",
        active: false,
        lock_version: @cash.lock_version
      }
    }
    @cash.reload
    assert_redirected_to admin_tender_type_path(@cash)
    assert_equal "Cash drawer", @cash.name
    assert_equal "cash", @cash.behavioral_category
    assert @cash.active?
    assert @cash.allows_refund?
    assert AuditEvent.exists?(action: "tender_types.update", subject_id: @cash.id)
  end

  test "admin can set Allow refunds on Card Check and Other and Cash stays true" do
    sign_in_as("admin")
    card = TenderType.find_by!(code: "card")
    check_type = TenderType.find_by!(code: "check")

    get new_admin_tender_type_path
    assert_response :success
    assert_select "input[name='tender_type[allows_refund]']"

    post admin_tender_types_path, params: {
      tender_type: {
        code: "store_voucher",
        name: "Store voucher",
        external_reference_policy: "optional"
      }
    }
    voucher = TenderType.find_by!(code: "store_voucher")
    assert_not voucher.allows_refund?
    create_audit = AuditEvent.find_by!(action: "tender_types.create", subject_id: voucher.id)
    assert_equal false, create_audit.after_values.fetch("allows_refund")

    get edit_admin_tender_type_path(@cash)
    assert_response :success
    assert_select "input[name='allows_refund_display'][disabled]"

    patch admin_tender_type_path(@cash), params: {
      tender_type: { name: @cash.name, allows_refund: "0", lock_version: @cash.lock_version }
    }
    assert @cash.reload.allows_refund?

    patch admin_tender_type_path(card), params: {
      tender_type: { name: card.name, allows_refund: "0", lock_version: card.lock_version }
    }
    assert_not card.reload.allows_refund?
    card_audit = AuditEvent.where(action: "tender_types.update", subject_id: card.id).order(:created_at).last
    assert_equal false, card_audit.after_values.fetch("allows_refund")

    patch admin_tender_type_path(check_type), params: {
      tender_type: { name: check_type.name, allows_refund: "1", lock_version: check_type.lock_version }
    }
    assert check_type.reload.allows_refund?

    patch admin_tender_type_path(voucher), params: {
      tender_type: { name: voucher.name, allows_refund: "1", lock_version: voucher.lock_version }
    }
    assert voucher.reload.allows_refund?

    get admin_tender_types_path
    assert_response :success
    assert_select "th", text: "Refunds"
  end

  test "associate is denied tender type administration" do
    associate = User.create!(
      username: "clerk",
      display_name: "Clerk",
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    RoleAssignment.create!(
      user: associate,
      role: Role.find_by!(key: "associate"),
      store: Store.first,
      assigned_by: User.find_by!(username: "admin"),
      effective_at: Time.current
    )

    sign_in_as("clerk")
    post admin_tender_types_path, params: {
      tender_type: { code: "denied", name: "Denied", external_reference_policy: "optional" }
    }
    assert_redirected_to root_path
    assert_not TenderType.exists?(code: "denied")
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end
end
