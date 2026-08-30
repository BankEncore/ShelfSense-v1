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

      lines = Pos::ShiftEndTape.lines(groups: groups, identity_lines: [ "X REPORT", "Store" ])
      assert lines.all? { |line| line.length <= Pos::ShiftEndTape::WIDTH }
      assert lines.any? { |line| line.include?("Cash payments") }
      assert lines.none? { |line| line.include?("Card payments") }
    end
  end
end
