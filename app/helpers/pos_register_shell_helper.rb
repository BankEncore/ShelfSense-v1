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
        "Business Date #{date.strftime("%a %d %b %y")}"
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

  def register_cluster_items
    kind = @state&.kind
    items = []
    items << { label: "Transactions", path: pos_transactions_path }
    if register_cluster_session_z?(kind)
      items << { label: "Session / Z Reports", path: pos_reports_path }
    end
    x_path = register_cluster_x_path(kind)
    items << { label: "X Report", path: x_path } if x_path
    if kind == "own_session"
      items.concat(register_cluster_till_items)
    end
    if can_view_other_sessions?
      items << { label: "Active Sessions", path: pos_active_sessions_path }
    end
    items << { label: "Switch Register", path: pos_switch_register_path }
    items
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

  private

  def register_cluster_session_z?(kind)
    return true if %w[closed between_sessions own_session].include?(kind)
    return can_view_other_sessions? if kind == "occupied"

    true
  end

  def register_cluster_x_path(kind)
    case kind
    when "own_session"
      pos_x_report_path
    when "occupied"
      return unless can_view_other_sessions?
      return if @gate&.session.blank?

      pos_session_x_report_path(@gate.session)
    end
  end

  def register_cluster_till_items
    items = []
    if pos_permission?("gift_cards.cash_out")
      items << { label: "Gift-card cash-out", path: new_pos_cash_out_path }
    end
    if pos_permission?("cash.paid_in")
      items << { label: "Paid-in", path: new_pos_cash_paid_in_path }
    end
    if pos_permission?("cash.paid_out")
      items << { label: "Paid-out", path: new_pos_cash_paid_out_path }
    end
    items << { label: "Drop", path: new_pos_cash_drop_path }
    if pos_permission?("cash.move")
      items << { label: "Replenish", path: new_pos_cash_replenishment_path }
    end
    items
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
