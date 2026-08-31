# frozen_string_literal: true

module PosRegisterShellHelper
  def register_shell_title
    return "Select a Register" if @state&.kind == "selector" || @switch_register
    return "Register #{@register.register_number}" if @register

    "Register"
  end

  def register_leave_confirm_options
    return {} if Array(@owned_sessions).empty?

    {
      data: {
        turbo_confirm: "Your session remains open. Leaving Register will not close it."
      }
    }
  end

  def register_header_business_date_text
    kind = register_header_state_kind
    case kind
    when "selector"
      "Business date not selected"
    when "closed"
      proposed = (@gate&.business_date || BusinessDate.for_store(current_store)).strftime("%a %d %b %y")
      "Business date not open · Proposed date: #{proposed}"
    when "between_sessions", "own_session", "occupied"
      date = @gate&.period&.business_date
      if date.present?
        "Business Date: #{date.strftime("%a %d %b %y")}"
      else
        "Business date not open"
      end
    else
      "Business date not selected"
    end
  end

  # Backward-compatible alias for the established-date format used in older call sites/tests.
  def register_header_business_date_label
    date = @gate&.period&.business_date
    return "—" if date.blank?

    date.strftime("%a %d %b %y")
  end

  def register_header_opened_at_label
    opened_at = @gate&.session&.opened_at
    return if opened_at.blank?

    zone = ActiveSupport::TimeZone[current_store.timezone] || ActiveSupport::TimeZone["UTC"]
    opened_at.in_time_zone(zone).strftime("%d %b %y %I:%M %P")
  end

  def register_menu_groups
    Pos::RegisterMenu.call(
      kind: register_menu_kind,
      surface: register_menu_surface,
      permissions: register_menu_permissions,
      gate: @gate
    ).groups
  end

  def register_menu_presentation(group)
    group.item_keys.filter_map { |key| register_menu_item(key) }
  end

  def register_menu_group_label(key)
    {
      customer_service: "Customer service",
      till: "Till",
      session_and_register: "Session & Register"
    }.fetch(key)
  end

  def register_selector_rows
    Array(@registers).map { |register| register_selector_row(register) }
  end

  def register_selector_row(register)
    gate = Pos::OpenGate.for(store: current_store, register: register, actor: current_user)
    owned = gate.own_session?
    {
      register: register,
      gate: gate,
      owned: owned,
      status: register_selector_status_text(gate),
      resume_path: owned ? pos_register_workspace_path(register_id: register.id) : nil,
      view_path: pos_path(register_id: register.id)
    }
  end

  def register_custody_warning?
    return false if @register.blank?

    Array(@owned_sessions).any? && Array(@owned_sessions).none? { |session| session.register_id == @register.id }
  end

  def register_multiple_owned_warning?
    Array(@owned_sessions).many? && (@state&.kind == "selector" || @switch_register)
  end

  def register_enter_submit_label
    return "Resume Register" if @gate&.own_session?
    return "Open session" if @gate&.can_finalize_period?

    "Open register"
  end

  def register_enter_proxy_name
    return "open-session" if @gate&.period.present? && @gate.session.nil?
    return "resume-register" if @gate&.own_session?

    "open-register"
  end

  private

  MENU_PERMISSION_KEYS = %w[
    pos.sessions.view
    gift_cards.cash_out
    cash.paid_in
    cash.paid_out
    cash.move
  ].freeze

  def register_menu_kind
    @state&.kind.presence || "selector"
  end

  def register_menu_surface
    return :switch_register if @switch_register
    return :workspace if controller_path == "pos/workspaces"
    return @shell_context.menu_surface if @shell_context.respond_to?(:menu_surface)

    :state_landing
  end

  def register_inquiry_return_path
    return @shell_context.return_path if @shell_context.respond_to?(:return_path)

    pos_resume_register_path
  end

  def register_inquiry_return_label
    return @shell_context.return_label if @shell_context.respond_to?(:return_label)

    "Close"
  end

  def register_menu_permissions
    MENU_PERMISSION_KEYS.select { |key| pos_permission?(key) }
  end

  def register_menu_item(key)
    case key
    when :transactions
      { key:, label: "Transactions & Receipts", href: pos_transactions_path(inquiry_register_params) }
    when :stored_value_inquiry
      { key:, label: "Stored Value Inquiry", href: pos_stored_value_inquiry_path(inquiry_register_params) }
    when :customer_summary
      { key:, label: "Customer Summary", href: pos_customer_summary_path(inquiry_register_params) }
    when :pickup_queue
      { key:, label: "Pickup Queue", href: pos_pickup_queue_path(inquiry_register_params) }
    when :till_activity
      { key:, label: "Till Activity", href: pos_till_activity_path(inquiry_register_params) }
    when :session_details
      session_record = @gate&.session || @shell_context&.session
      return if session_record.blank?

      { key:, label: "Session Details", href: pos_session_details_path(session_record, inquiry_register_params) }
    when :gift_card_cash_out
      { key:, label: "Gift-card cash-out", href: new_pos_cash_out_path }
    when :paid_in
      { key:, label: "Paid-in", href: new_pos_cash_paid_in_path }
    when :paid_out
      { key:, label: "Paid-out", href: new_pos_cash_paid_out_path }
    when :drop
      { key:, label: "Drop", href: new_pos_cash_drop_path }
    when :replenish
      { key:, label: "Replenish", href: new_pos_cash_replenishment_path }
    when :x_report
      href = register_menu_x_path
      return if href.blank?

      { key:, label: "X Report", href: href }
    when :session_z_reports
      { key:, label: "Session / Z Reports", href: register_menu_z_path }
    when :active_sessions
      { key:, label: "Active Sessions", href: pos_active_sessions_path(inquiry_register_params) }
    when :switch_register
      { key:, label: "Switch Register", href: pos_switch_register_path }
    when :open_register
      { key:, label: "Open Register", proxy: "open-register" }
    when :open_session
      { key:, label: "Open Session", proxy: "open-session" }
    when :finalize_z
      { key:, label: "Finalize Z", proxy: "finalize-z" }
    when :close_session
      { key:, label: "Close Session", proxy: "close-session" }
    when :return_to_shelfsense
      { key:, label: "Return to ShelfSense", href: root_path, leave: true }
    end
  end

  def register_menu_x_path
    return pos_x_report_path if register_menu_kind == "own_session"
    return if @gate&.session.blank?

    pos_session_x_report_path(@gate.session)
  end

  def register_menu_z_path
    period = @gate&.period
    if period&.finalized?
      pos_reporting_period_z_path(period)
    elsif period&.open?
      pos_reporting_period_status_path(period)
    else
      pos_z_status_path(inquiry_register_params)
    end
  end

  def pos_permission?(key)
    Authorization::PermissionEvaluator.allowed?(user: current_user, permission_key: key, store: current_store)
  end

  def register_header_state_kind
    return "selector" if @switch_register
    return @state.kind if @state.respond_to?(:kind) && @state.kind.present?
    return "own_session" if @gate&.own_session?
    return "occupied" if @gate&.occupied?
    return "between_sessions" if @gate&.period.present?
    return "closed" if @register.present?

    "selector"
  end

  def register_selector_status_text(gate)
    if gate.own_session?
      "Your session — #{gate.business_date.iso8601}"
    elsif gate.occupied?
      "In use by #{gate.occupier.display_name}"
    elsif gate.leftover_period?
      "Prior date open · #{gate.business_date.iso8601}"
    elsif gate.period.present?
      "Between sessions · #{gate.business_date.iso8601}"
    else
      "Closed"
    end
  end
end
