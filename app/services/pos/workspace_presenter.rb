# frozen_string_literal: true

module Pos
  class WorkspacePresenter
    SummaryRow = Data.define(:key, :label, :signed_cents)
    TaxGroup = Data.define(:store_tax_id, :code, :name, :rate_percent, :calculation_order, :signed_cents) do
      def label
        percent = format("%.3f", rate_percent)
        "#{name} #{percent}%"
      end

      def key
        [ store_tax_id, code, name, rate_percent.to_s, calculation_order ].join(":")
      end
    end
    TenderRow = Data.define(
      :id,
      :label,
      :amount_cents,
      :direction,
      :presented_cents,
      :change_cents,
      :ordinary,
      :stored_value,
      :behavioral_category,
      :external_reference,
      :edit_available,
      :remove_available,
      :edit_unavailable_reason,
      :remove_unavailable_reason,
      :inspect_detail
    )
    SettlementCue = Data.define(:kind, :label, :amount_cents)
    Result = Data.define(
      :mode_label,
      :command_label,
      :command_inputmode,
      :command_value,
      :locked,
      :completion_recovery,
      :refund_mode,
      :summary_rows,
      :tax_groups,
      :tax_fallback,
      :tender_rows,
      :settlement_cues,
      :close_session_available,
      :issuance_remove_available,
      :pickup_available,
      :gift_card_programs_available,
      :cancel_consequence,
      :feedback
    )

    def self.call(...)
      new(...).call
    end

    def initialize(
      transaction:,
      lines:,
      tenders:,
      issuances:,
      selected_line:,
      selected_tender_type:,
      ui_mode:,
      settlement_direction:,
      remaining_payment_cents:,
      remaining_refund_cents:,
      command_value:,
      feedback:,
      action_capabilities:,
      selected_tender: nil
    )
      @transaction = transaction
      @lines = Array(lines)
      @tenders = Array(tenders)
      @issuances = Array(issuances)
      @selected_line = selected_line
      @selected_tender_type = selected_tender_type
      @selected_tender = selected_tender
      @ui_mode = ui_mode.to_s
      @settlement_direction = settlement_direction.to_sym
      @remaining_payment_cents = remaining_payment_cents.to_i
      @remaining_refund_cents = remaining_refund_cents.to_i
      @command_value = command_value
      @feedback = feedback
      @action_capabilities = (action_capabilities || {}).transform_keys(&:to_sym)
    end

    def call
      tax = build_tax_groups
      summary = build_summary_rows(tax[:groups], tax[:fallback])
      assert_summary_reconciles!(summary)

      Result.new(
        mode_label: mode_label,
        command_label: command_label,
        command_inputmode: command_inputmode,
        command_value: resolved_command_value,
        locked: locked?,
        completion_recovery: completion_recovery?,
        refund_mode: refund_mode?,
        summary_rows: summary,
        tax_groups: tax[:groups],
        tax_fallback: tax[:fallback],
        tender_rows: build_tender_rows,
        settlement_cues: build_settlement_cues,
        close_session_available: capability?(:close_session_available),
        issuance_remove_available: capability?(:issuance_remove_available),
        pickup_available: capability?(:pickup_available),
        gift_card_programs_available: capability?(:gift_card_programs_available),
        cancel_consequence: cancel_consequence,
        feedback: @feedback
      )
    end

    private

    def cancel_consequence
      parts = []
      sale_qty = @lines.select(&:sale?).sum { |line| line.quantity.to_i }
      return_qty = @lines.select(&:return?).sum { |line| line.quantity.to_i.abs }
      activation_count = @issuances.count(&:activation?)
      reload_count = @issuances.count(&:reload_issuance?)
      parts << "#{sale_qty} #{sale_qty == 1 ? "item" : "items"} for sale" if sale_qty.positive?
      parts << "#{return_qty} #{return_qty == 1 ? "returned item" : "returned items"}" if return_qty.positive?
      if activation_count.positive?
        parts << "#{activation_count} gift card #{activation_count == 1 ? "activation" : "activations"}"
      end
      if reload_count.positive?
        parts << "#{reload_count} gift card #{reload_count == 1 ? "reload" : "reloads"}"
      end
      return "All working content will be discarded." if parts.empty?

      list =
        if parts.length == 1
          parts.first
        elsif parts.length == 2
          "#{parts[0]} and #{parts[1]}"
        else
          "#{parts[0...-1].join(", ")}, and #{parts[-1]}"
        end
      "#{list} will be discarded."
    end

    def locked?
      %w[completion_pending completion_failed].include?(@ui_mode)
    end

    def completion_recovery?
      @ui_mode == "completion_failed"
    end

    def refund_mode?
      @settlement_direction == :refund
    end

    def capability?(key)
      @action_capabilities.fetch(key, false) ? true : false
    end

    def cash_selected?
      @selected_tender_type&.cash?
    end

    def mode_label
      return "QUANTITY" if @ui_mode == "quantity"
      return "SALE ENTRY" if @ui_mode == "sale_entry"
      return "REFUND" if refund_mode?

      if cash_selected? || locked?
        "CASH TENDER"
      else
        "TENDER"
      end
    end

    def remaining_cents
      refund_mode? ? @remaining_refund_cents : @remaining_payment_cents
    end

    def remaining_label
      amount = format_money(remaining_cents)
      refund_mode? ? "Refund remaining #{amount}" : "Balance due #{amount}"
    end

    def command_label
      if @ui_mode == "quantity" && @selected_line
        "#{line_description(@selected_line)} · Current quantity #{@selected_line.quantity}"
      elsif @ui_mode == "tender"
        if refund_mode?
          cash_selected? ? "#{remaining_label}. Refund amount" : "#{remaining_label}. #{@selected_tender_type&.name} amount"
        elsif cash_selected?
          "#{remaining_label}. Cash presented"
        else
          "Remaining #{format_money(remaining_cents)}. #{@selected_tender_type&.name} amount"
        end
      elsif locked?
        refund_mode? ? "Refund (locked)" : "Tender (locked)"
      else
        "Scan or identifier"
      end
    end

    def command_inputmode
      case @ui_mode
      when "quantity" then "numeric"
      when "tender" then "decimal"
      else "text"
      end
    end

    def resolved_command_value
      return @command_value if @command_value.present?
      return format_field_cents(@remaining_refund_cents) if @ui_mode == "tender" && refund_mode?

      @command_value
    end

    def line_description(line)
      snapshot = line.merchandise_snapshot
      return "Line" unless snapshot.is_a?(Hash)

      snapshot["description"].presence || "Line"
    end

    def build_tax_groups
      buckets = Hash.new { |hash, key| hash[key] = { signed_cents: 0, meta: nil } }

      @lines.each do |line|
        line.pos_line_tax_components.each do |component|
          next unless component.applies

          signed = line.sale? ? component.tax_cents.to_i : -component.tax_cents.to_i
          key = [
            component.store_tax_id,
            component.store_tax_code_snapshot,
            component.store_tax_name_snapshot,
            component.rate_percent.to_s,
            component.calculation_order
          ]
          buckets[key][:signed_cents] += signed
          buckets[key][:meta] ||= component
        end
      end

      groups = buckets.filter_map do |key, bucket|
        next if bucket[:signed_cents].zero?

        meta = bucket[:meta]
        TaxGroup.new(
          store_tax_id: key[0],
          code: key[1],
          name: key[2],
          rate_percent: meta.rate_percent,
          calculation_order: key[4],
          signed_cents: bucket[:signed_cents]
        )
      end

      groups.sort_by! { |group| [ group.calculation_order, group.name.to_s, group.code.to_s ] }

      expected = @transaction.tax_cents.to_i - @transaction.return_tax_cents.to_i
      actual = groups.sum(&:signed_cents)
      if actual == expected
        { groups: groups, fallback: false }
      else
        Rails.logger.warn(
          "[Pos::WorkspacePresenter] tax group mismatch transaction_id=#{@transaction.id} " \
          "grouped=#{actual} expected=#{expected}"
        )
        fallback_group = TaxGroup.new(
          store_tax_id: nil,
          code: "net_tax",
          name: "Net tax",
          rate_percent: 0,
          calculation_order: 0,
          signed_cents: expected
        )
        { groups: expected.zero? ? [] : [ fallback_group ], fallback: true }
      end
    end

    def build_summary_rows(tax_groups, fallback)
      rows = []
      append_row!(rows, :merchandise, "Merchandise", @transaction.subtotal_cents.to_i)
      append_row!(rows, :discount, "Discount", -@transaction.discount_cents.to_i)
      append_row!(rows, :returns, "Returns", -@transaction.return_subtotal_cents.to_i)
      append_row!(rows, :return_discount_reversal, "Return discount reversal", @transaction.return_discount_cents.to_i)
      append_row!(rows, :gift_cards_issued, "Gift cards issued", @transaction.stored_value_issuance_cents.to_i)

      tax_groups.each do |group|
        label = fallback && group.code == "net_tax" ? "Net tax" : group.label
        rows << SummaryRow.new(key: :"tax_#{group.key}", label: label, signed_cents: group.signed_cents)
      end

      rows << SummaryRow.new(key: :net, label: "Net", signed_cents: @transaction.signed_net_cents.to_i)
      rows
    end

    def append_row!(rows, key, label, signed_cents)
      return if signed_cents.zero?

      rows << SummaryRow.new(key: key, label: label, signed_cents: signed_cents)
    end

    def assert_summary_reconciles!(rows)
      total = rows.reject { |row| row.key == :net }.sum(&:signed_cents)
      return if total == @transaction.signed_net_cents.to_i

      Rails.logger.warn(
        "[Pos::WorkspacePresenter] summary mismatch transaction_id=#{@transaction.id} " \
        "rows=#{total} signed_net=#{@transaction.signed_net_cents}"
      )
    end

    def build_tender_rows
      distinguish_cash = @tenders.any? { |tender| tender.direction == "refund" }
      @tenders.map do |tender|
        affordances = tender_affordances(tender)
        TenderRow.new(
          id: tender.id,
          label: tender_label(tender, distinguish_cash:),
          amount_cents: tender.amount_cents.to_i,
          direction: tender.direction,
          presented_cents: tender.amount_presented_cents,
          change_cents: tender.change_cents,
          ordinary: !tender.stored_value?,
          stored_value: tender.stored_value?,
          behavioral_category: tender.behavioral_category,
          external_reference: tender.external_reference,
          edit_available: affordances.fetch(:edit_available),
          remove_available: affordances.fetch(:remove_available),
          edit_unavailable_reason: affordances.fetch(:edit_unavailable_reason),
          remove_unavailable_reason: affordances.fetch(:remove_unavailable_reason),
          inspect_detail: tender_inspect_detail(tender)
        )
      end
    end

    def tender_affordances(tender)
      if tender.stored_value?
        return {
          edit_available: false,
          remove_available: false,
          edit_unavailable_reason: "Stored-value tender correction becomes available after Slice 7B.",
          remove_unavailable_reason: "Stored-value tender correction becomes available after Slice 7B."
        }
      end

      if tender.behavioral_category == "card"
        return {
          edit_available: false,
          remove_available: true,
          edit_unavailable_reason: "Card tenders must be removed and re-authorized externally before recording a replacement.",
          remove_unavailable_reason: nil
        }
      end

      {
        edit_available: %w[cash check other].include?(tender.behavioral_category),
        remove_available: true,
        edit_unavailable_reason: nil,
        remove_unavailable_reason: nil
      }
    end

    def tender_inspect_detail(tender)
      details = [ "#{tender.direction.capitalize} #{format_money(tender.amount_cents)}" ]
      details << "Presented #{format_money(tender.amount_presented_cents)}" if tender.amount_presented_cents.present?
      details << "Change #{format_money(tender.change_cents)}" if tender.change_cents.to_i.positive?
      details << "Reference #{tender.external_reference}" if tender.external_reference.present?
      details.join(" · ")
    end

    def tender_label(tender, distinguish_cash:)
      if tender.direction == "refund"
        "#{tender.tender_name} refund"
      elsif tender.cash? && distinguish_cash
        "#{tender.tender_name} payment"
      else
        tender.tender_name
      end
    end

    def build_settlement_cues
      cues = []

      if @ui_mode == "completion_pending"
        cues << SettlementCue.new(kind: :completing, label: "Completing", amount_cents: nil)
      elsif @ui_mode == "completion_failed"
        cues << SettlementCue.new(kind: :completion_failed, label: "Completion Failed", amount_cents: nil)
      elsif even_exchange? && @ui_mode == "sale_entry"
        cues << SettlementCue.new(kind: :even_exchange, label: "Even exchange", amount_cents: nil)
      elsif exact_settlement?
        cues << SettlementCue.new(kind: :settled, label: "Settled", amount_cents: 0)
        cash_payment = @tenders.find { |tender| tender.cash? && tender.direction == "payment" }
        if cash_payment && cash_payment.change_cents.to_i.positive?
          cues << SettlementCue.new(kind: :change, label: "CHANGE", amount_cents: cash_payment.change_cents.to_i)
        end
      elsif refund_mode?
        cues << SettlementCue.new(kind: :refund_remaining, label: "Refund remaining", amount_cents: @remaining_refund_cents)
      elsif @settlement_direction == :payment
        cues << SettlementCue.new(kind: :balance_due, label: "Balance due", amount_cents: @remaining_payment_cents)
      end

      cues
    end

    def exact_settlement?
      case @settlement_direction
      when :none
        commercial_content? && @tenders.empty?
      when :payment
        @tenders.any? &&
          @tenders.all? { |tender| tender.direction == "payment" } &&
          @remaining_payment_cents.zero?
      when :refund
        @tenders.any? &&
          @tenders.all? { |tender| tender.direction == "refund" } &&
          @remaining_refund_cents.zero?
      else
        false
      end
    end

    def even_exchange?
      @transaction.signed_net_cents.to_i.zero? &&
        @lines.any?(&:sale?) &&
        @lines.any?(&:return?)
    end

    def commercial_content?
      @lines.any? || @issuances.any? || @transaction.stored_value_issuance_cents.to_i != 0
    end

    def format_money(cents)
      dollars = cents.to_i / 100
      remainder = cents.to_i.abs % 100
      sign = cents.to_i.negative? ? "-" : ""
      "#{sign}$#{dollars.abs}.#{format('%02d', remainder)}"
    end

    def format_field_cents(cents)
      format("%.2f", cents.to_i / 100.0)
    end
  end
end
