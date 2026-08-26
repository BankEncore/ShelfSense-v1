# frozen_string_literal: true

require "test_helper"

module GiftCards
  class NumberTest < ActiveSupport::TestCase
    test "present groups prefix, four-digit body blocks, and check digit" do
      assert_equal "801 6592 9340 5700 4387 9",
                   GiftCards::Number.present("80165929340570043879", prefix: "801")
      assert_equal "801 6592 9340 5700 4387 9",
                   GiftCards::Number.present("801-6592-9340-5700-4387-9", prefix: "801")
    end

    test "present keeps a longer prefix intact" do
      assert_equal "80 1659 2934 0570 0438 7",
                   GiftCards::Number.present("8016592934057004387", prefix: "80")
    end
  end
end
