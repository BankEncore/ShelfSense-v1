# frozen_string_literal: true

module Installation
  class Bootstrap
    class AlreadyInitialized < StandardError; end
    class InvalidInput < StandardError; end

    ADVISORY_LOCK_KEY = 870_109_001

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      organization_name:,
      store_number:,
      store_code:,
      store_name:,
      store_timezone:,
      store_country_code:,
      admin_username:,
      admin_display_name:,
      admin_password:,
      admin_email: nil,
      base_currency_code: "USD",
      default_timezone: nil,
      default_country_code: nil,
      legal_name: nil,
      store_legal_name: nil
    )
      @organization_name = organization_name
      @legal_name = legal_name
      @store_legal_name = store_legal_name
      @store_number = store_number
      @store_code = store_code
      @store_name = store_name
      @store_timezone = store_timezone
      @store_country_code = store_country_code
      @admin_username = admin_username
      @admin_display_name = admin_display_name
      @admin_password = admin_password
      @admin_email = admin_email
      @base_currency_code = base_currency_code
      @default_timezone = default_timezone || store_timezone
      @default_country_code = default_country_code || store_country_code
    end

    def call
      validate_input!

      ActiveRecord::Base.transaction do
        acquire_advisory_lock!
        raise AlreadyInitialized, "ShelfSense is already initialized" if SystemSettings.initialized?

        correlation_id = SecureRandom.uuid_v7
        settings = create_settings!
        system_user = create_system_user!
        Authorization::PermissionCatalog.seed!(granted_by: system_user)
        ProductForms::Catalog.seed!
        SubjectSchemes::Catalog.seed!
        Inventory::AdjustmentReasons.seed!
        StoredValue::AdjustmentReasons.seed!
        Cash::ActivityReasons.seed!
        GiftCards::Programs.seed!
        Pos::TenderTypes.seed!

        Audit::Recorder.record!(
          action: "installation.started",
          outcome: "succeeded",
          actor_user: system_user,
          actor_type: "system",
          actor_label: system_user.display_name,
          correlation_id: correlation_id,
          subject: settings,
          after_values: { organization_name: settings.organization_name }
        )

        store = create_store!
        Audit::Recorder.record!(
          action: "stores.create",
          outcome: "succeeded",
          actor_user: system_user,
          actor_type: "system",
          actor_label: system_user.display_name,
          store: store,
          correlation_id: correlation_id,
          subject: store,
          after_values: { code: store.code, name: store.name }
        )

        admin = create_administrator!
        assignment = assign_administrator!(admin: admin, system_user: system_user)
        approver = create_safe_approver!
        assign_safe_approver!(approver: approver, system_user: system_user, store: store)
        Cash::InitializeSafe.call(
          store: store,
          performed_by: admin,
          approved_by: approver,
          count_cents: 100_000,
          source_id: SecureRandom.uuid_v7,
          idempotency_key: SecureRandom.uuid_v7,
          notes: "Bootstrap safe initialization"
        )

        Audit::Recorder.record!(
          action: "users.create",
          outcome: "succeeded",
          actor_user: system_user,
          actor_type: "system",
          actor_label: system_user.display_name,
          correlation_id: correlation_id,
          subject: admin,
          after_values: { username: admin.username, display_name: admin.display_name }
        )
        Audit::Recorder.record!(
          action: "role_assignments.create",
          outcome: "succeeded",
          actor_user: system_user,
          actor_type: "system",
          actor_label: system_user.display_name,
          correlation_id: correlation_id,
          subject: assignment,
          after_values: { user_id: admin.id, role_key: "system_administrator", store_id: nil }
        )

        settings.update!(initialized_at: Time.current)
        Audit::Recorder.record!(
          action: "installation.completed",
          outcome: "succeeded",
          actor_user: system_user,
          actor_type: "system",
          actor_label: system_user.display_name,
          correlation_id: correlation_id,
          subject: settings,
          after_values: { initialized_at: settings.initialized_at.iso8601 }
        )

        { settings: settings, store: store, system_user: system_user, administrator: admin, assignment: assignment, safe_approver: approver }
      end
    end

    private

    attr_reader :organization_name, :legal_name, :store_legal_name, :store_number, :store_code, :store_name,
                :store_timezone, :store_country_code, :admin_username, :admin_display_name,
                :admin_password, :admin_email, :base_currency_code, :default_timezone, :default_country_code

    def validate_input!
      raise InvalidInput, "admin password is required" if admin_password.blank?
      raise InvalidInput, "organization name is required" if organization_name.blank?
      raise InvalidInput, "store legal name is required" if store_legal_name.blank?
    end

    def acquire_advisory_lock!
      locked = ActiveRecord::Base.connection.select_value(
        ActiveRecord::Base.sanitize_sql_array([ "SELECT pg_try_advisory_xact_lock(?)", ADVISORY_LOCK_KEY ])
      )
      raise AlreadyInitialized, "Bootstrap is already in progress or completed" unless locked
    end

    def create_settings!
      SystemSettings.create!(
        singleton_key: true,
        organization_name: organization_name,
        legal_name: legal_name,
        base_currency_code: base_currency_code,
        default_timezone: default_timezone,
        default_country_code: default_country_code
      )
    end

    def create_system_user!
      User.create!(
        username: User::SYSTEM_USERNAME,
        display_name: "System",
        actor_type: "system",
        active: true
      )
    end

    def create_store!
      Store.create!(
        store_number: store_number,
        code: store_code,
        name: store_name,
        legal_name: store_legal_name,
        timezone: store_timezone,
        country_code: store_country_code
      )
    end

    def create_administrator!
      User.create!(
        username: admin_username,
        email: admin_email,
        display_name: admin_display_name,
        actor_type: "human",
        password: admin_password,
        password_confirmation: admin_password,
        password_changed_at: Time.current,
        active: true
      )
    end

    def assign_administrator!(admin:, system_user:)
      role = Role.find_by!(key: "system_administrator")
      RoleAssignment.create!(
        user: admin,
        role: role,
        store: nil,
        assigned_by: system_user,
        effective_at: Time.current
      )
    end

    def create_safe_approver!
      User.create!(
        username: "safe-approver",
        display_name: "Safe approver",
        actor_type: "human",
        password: @admin_password,
        password_confirmation: @admin_password,
        password_changed_at: Time.current,
        active: true
      )
    end

    def assign_safe_approver!(approver:, system_user:, store:)
      RoleAssignment.create!(
        user: approver,
        role: Role.find_by!(key: "store_manager"),
        store: store,
        assigned_by: system_user,
        effective_at: Time.current
      )
    end
  end
end
