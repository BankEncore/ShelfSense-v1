# frozen_string_literal: true

require "test_helper"

class Pos::Code128Test < ActiveSupport::TestCase
  PAYLOAD = "S001-R01-T0000001"

  test "svg encodes payload with quiet zone for thermal print scaling" do
    svg = Pos::Code128.svg(PAYLOAD)

    assert_includes svg, PAYLOAD
    assert_includes svg, "<svg"
    assert_includes svg, "<rect"
    assert_match(/viewBox="0 0 (\d+) 40"/, svg)
    width = svg.match(/viewBox="0 0 (\d+) 40"/)[1].to_i
    assert_operator width, :>, 200
  end

  test "checksum uses the deployed Code 128 B weighting" do
    values = [ Pos::Code128::START_B, "A".ord - 32 ]
    checksum = values.each_with_index.sum { |value, index| value * [ 1, index ].max } % 103

    assert_equal 34, checksum
  end

  test "changing payload changes encoded bar pattern" do
    first = Pos::Code128.svg(PAYLOAD)
    second = Pos::Code128.svg("S001-R01-T0000002")

    refute_equal first, second
  end
end
