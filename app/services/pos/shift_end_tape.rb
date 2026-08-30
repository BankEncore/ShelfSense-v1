# frozen_string_literal: true

module Pos
  # Compact 42-character monospaced tape from the same P13 OperatorReport groups.
  class ShiftEndTape
    WIDTH = 42

    def self.lines(groups:, identity_lines:)
      new(groups: groups, identity_lines: identity_lines).lines
    end

    def initialize(groups:, identity_lines:)
      @groups = groups
      @identity_lines = Array(identity_lines)
    end

    def lines
      out = []
      @identity_lines.each { |line| out << clip(line) }
      out << ("-" * WIDTH)
      @groups.each do |group|
        next if group.rows.empty?

        essential = essential_rows(group)
        next if essential.empty?

        out << clip(group.title.upcase)
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
          format_signed(row.cents)
        else
          format_money(row.cents)
        end
      pad_row(row.label, value)
    end

    def pad_row(label, value)
      room = WIDTH - value.length
      left = clip(label, room)
      spaces = [ WIDTH - left.length - value.length, 1 ].max
      "#{left}#{' ' * spaces}#{value}"[0, WIDTH]
    end

    def clip(text, width = WIDTH)
      text.to_s[0, width]
    end

    def format_money(cents)
      sign = cents.to_i.negative? ? "-" : ""
      absolute = cents.to_i.abs
      "#{sign}$#{absolute / 100}.#{format('%02d', absolute % 100)}"
    end

    def format_signed(cents)
      format_money(cents)
    end
  end
end
