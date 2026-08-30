# frozen_string_literal: true

require "test_helper"

module Pos
  class ShiftEndTapeTest < ActiveSupport::TestCase
    test "lines are at most 42 characters and omit zero tenders" do
      groups = [
        Pos::OperatorReport::Group.new(
          title: "Sales",
          rows: [
            Pos::OperatorReport::Row.new(label: "Transactions", cents: 2, format: :count),
            Pos::OperatorReport::Row.new(label: "Gross sales", cents: 1000, format: :money),
            Pos::OperatorReport::Row.new(label: "Sales total", cents: 1100, format: :money)
          ]
        ),
        Pos::OperatorReport::Group.new(
          title: "Tenders",
          rows: [
            Pos::OperatorReport::Row.new(label: "Cash payments", cents: 1100, format: :money),
            Pos::OperatorReport::Row.new(label: "Card payments", cents: 0, format: :money)
          ]
        )
      ]
      identity = Pos::ShiftEndTape::Identity.new(
        report_type: "X REPORT",
        store_label: "A very long store label that must wrap across multiple tape lines without silent clipping of meaning",
        register_label: "01 Front",
        business_date: "2026-08-30",
        session_reference: "Session abc",
        cashier_label: "Cashier",
        opened_at_label: "2026-08-30 09:00",
        closed_at_label: nil,
        closed_by_label: nil,
        generated_at_label: "2026-08-30 12:00",
        reprint: false
      )

      lines = Pos::ShiftEndTape.lines(groups: groups, identity: identity)
      assert lines.all? { |line| line.length <= Pos::ShiftEndTape::WIDTH }
      assert lines.any? { |line| line.include?("Cash payments") }
      assert lines.none? { |row| row.include?("Card payments") }
      assert lines.any? { |line| line.include?("Session abc") }
      assert lines.count { |line| line.include?("long store") || line.include?("A very long") } >= 1
    end
  end
end
