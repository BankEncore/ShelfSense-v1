# frozen_string_literal: true

module Pos
  class ShiftEndTape
    WIDTH = 42

    Identity = Data.define(
      :report_type,
      :store_label,
      :register_label,
      :business_date,
      :session_reference,
      :cashier_label,
      :opened_at_label,
      :closed_at_label,
      :closed_by_label,
      :generated_at_label,
      :reprint
    ) do
      def lines
        out = [ report_type.to_s ]
        out << store_label.to_s
        out << register_label.to_s
        out << "Business date #{business_date}" if business_date.present?
        out << session_reference.to_s if session_reference.present?
        out << "Cashier #{cashier_label}" if cashier_label.present?
        out << "Opened #{opened_at_label}" if opened_at_label.present?
        out << "Closed #{closed_at_label}" if closed_at_label.present?
        out << "Closed by #{closed_by_label}" if closed_by_label.present?
        out << "Printed #{generated_at_label}" if generated_at_label.present?
        out << "REPRINT" if reprint
        out
      end
    end

    def self.lines(groups:, identity:)
      new(groups: groups, identity: identity).lines
    end

    def initialize(groups:, identity:)
      @groups = groups
      @identity = identity
    end

    def lines
      out = []
      identity_source = @identity.respond_to?(:lines) ? @identity.lines : Array(@identity)
      identity_source.each { |line| out.concat(wrap(line)) }
      out << ("-" * WIDTH)
      @groups.each do |group|
        next if group.rows.empty?

        essential = essential_rows(group)
        next if essential.empty?

        out.concat(wrap(group.title.upcase))
        essential.each do |row|
          out << format_row(row)
        end
      end
      out
    end

    private

    def essential_rows(group)
      case group.title
      when "Sales"
        group.rows.select { |row| [ "Transactions", "Gross sales", "Sales total" ].include?(row.label) }
      when "Net"
        group.rows
      when "Tenders"
        group.rows.reject { |row| row.cents.to_i.zero? }
      when "Stored value"
        group.rows.reject { |row| row.format == :count || row.cents.to_i.zero? }
      when "Cash custody"
        group.rows.select do |row|
          [
            "Opening float",
            "Expected Cash",
            "Expected closing Cash",
            "Counted Cash",
            "Counted closing Cash",
            "Variance",
            "Closing variance",
            "Sessions"
          ].include?(row.label) || (row.cents.to_i != 0 && operational?(row.label))
        end
      when "Post-void"
        group.rows.reject { |row| row.cents.to_i.zero? }
      else
        group.rows.reject { |row| row.format != :count && row.cents.to_i.zero? }
      end
    end

    def operational?(label)
      %w[Paid-in Paid-out Drops Replenishments].include?(label) ||
        [ "Cash-operation reversals", "Non-sale cash" ].include?(label)
    end

    def format_row(row)
      value =
        case row.format
        when :count
          row.cents.to_s
        when :signed
          format_money(row.cents)
        else
          format_money(row.cents)
        end
      pad_row(row.label, value)
    end

    def pad_row(label, value)
      room = WIDTH - value.length
      left = label.to_s[0, [ room, 0 ].max]
      spaces = [ WIDTH - left.length - value.length, 1 ].max
      "#{left}#{' ' * spaces}#{value}"[0, WIDTH]
    end

    def wrap(text, width = WIDTH)
      str = text.to_s
      return [ "" ] if str.empty?

      str.scan(/.{1,#{width}}/m)
    end

    def format_money(cents)
      sign = cents.to_i.negative? ? "-" : ""
      absolute = cents.to_i.abs
      "#{sign}$#{absolute / 100}.#{format('%02d', absolute % 100)}"
    end
  end
end
