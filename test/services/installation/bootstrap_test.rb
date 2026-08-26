# frozen_string_literal: true

require "test_helper"

class Installation::BootstrapTest < ActiveSupport::TestCase
  setup do
    @attrs = {
      organization_name: "Example Books",
      store_number: "1",
      store_code: "main",
      store_name: "Main Store",
      store_legal_name: "Example Books LLC",
      store_timezone: "America/New_York",
      store_country_code: "US",
      admin_username: "admin",
      admin_display_name: "Admin User",
      admin_password: "correct-horse-battery",
      admin_email: "admin@example.com"
    }
  end

  test "bootstraps organization store system actor admin and audit events" do
    result = Installation::Bootstrap.call(**@attrs)

    assert SystemSettings.initialized?
    assert_equal "Example Books", result[:settings].organization_name
    assert_equal "main", result[:store].code
    assert_equal "Example Books LLC", result[:store].legal_name
    refute_equal result[:store].name, result[:store].legal_name
    assert result[:system_user].system_actor?
    assert_nil result[:system_user].password_digest
    assert result[:administrator].authenticate("correct-horse-battery")
    assert_equal "system_administrator", result[:assignment].role.key
    assert_nil result[:assignment].store_id

    assert_equal Authorization::PermissionCatalog::PERMISSIONS.size, Permission.active.count
    assert_equal 3, Role.count
    assert Role.find_by!(key: "store_manager").assignment_scope == "store"

    admin_role = Role.find_by!(key: "system_administrator")
    assert_equal Authorization::PermissionCatalog::PERMISSIONS.map { |p| p[:key] }.sort,
                 admin_role.permissions.pluck(:key).sort
    Authorization::PermissionCatalog::PHASE2_PERMISSIONS.each do |permission|
      assert_includes admin_role.permissions.pluck(:key), permission[:key]
    end
    assert_includes admin_role.permissions.pluck(:key), "registers.view"
    assert_not_includes admin_role.permissions.pluck(:key), "workstations.revoke"
    revoke = Permission.find_by!(key: "workstations.revoke")
    assert_not revoke.active?

    actions = AuditEvent.order(:occurred_at).pluck(:action)
    assert_includes actions, "installation.started"
    assert_includes actions, "installation.completed"
    assert AuditEvent.where(actor_type: "system").exists?
    assert StoredValueAdjustmentReason.exists?(code: "goodwill")
    assert_not StoredValueAdjustmentReason.exists?(code: "opening_balance")
    assert GiftCardProgram.exists?(code: "generated")
    assert GiftCardProgram.exists?(code: "manual")
    assert_equal 5000, result[:settings].stored_value_adjust_credit_approval_threshold_cents
  end

  test "rejects a second bootstrap after initialization" do
    Installation::Bootstrap.call(**@attrs)

    assert_raises(Installation::Bootstrap::AlreadyInitialized) do
      Installation::Bootstrap.call(**@attrs.merge(admin_username: "admin2", store_code: "two", store_number: "2"))
    end
  end

  test "failed bootstrap leaves installation retryable" do
    assert_raises(ActiveRecord::RecordInvalid) do
      Installation::Bootstrap.call(**@attrs.merge(admin_password: "short"))
    end

    assert_not SystemSettings.initialized?
    assert_equal 0, User.count
    assert_equal 0, AuditEvent.count

    result = Installation::Bootstrap.call(**@attrs)
    assert SystemSettings.initialized?
    assert result[:administrator].persisted?
  end

  test "system actor cannot authenticate and cannot receive roles" do
    result = Installation::Bootstrap.call(**@attrs)
    system_user = result[:system_user]

    assert_not system_user.authenticatable?
    assignment = RoleAssignment.new(
      user: system_user,
      role: Role.find_by!(key: "associate"),
      store: result[:store],
      assigned_by: result[:administrator]
    )
    assert_not assignment.valid?
    assert_includes assignment.errors[:user_id], "system actor cannot receive role assignments"
  end

  test "store-only roles cannot be assigned globally" do
    result = Installation::Bootstrap.call(**@attrs)
    assignment = RoleAssignment.new(
      user: result[:administrator],
      role: Role.find_by!(key: "store_manager"),
      store: nil,
      assigned_by: result[:administrator]
    )
    assert_not assignment.valid?
  end

  test "last global administrator protection locks and rejects removal" do
    result = Installation::Bootstrap.call(**@attrs)
    assignment = result[:assignment]

    error = assert_raises(Authorization::LastGlobalAdministrator::WouldRemoveLastAdministrator) do
      Authorization::LastGlobalAdministrator.new.with_lock do
        assignment.update!(revoked_at: Time.current, revoked_by: result[:administrator], revocation_reason: "test")
      end
    end

    assert_match(/at least one active global system administrator/, error.message)
    assert_nil assignment.reload.revoked_at
  end

  test "requires a store legal name and does not copy the operational store name" do
    error = assert_raises(Installation::Bootstrap::InvalidInput) do
      Installation::Bootstrap.call(**@attrs.merge(store_legal_name: nil))
    end
    assert_match(/store legal name is required/, error.message)
    assert_not SystemSettings.initialized?
  end
end
