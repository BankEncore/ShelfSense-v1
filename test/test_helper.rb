ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "support/phase2_fixtures"
require_relative "support/pos_fixtures"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Fixtures are opt-in per test case until a stable fixture set exists.
    # fixtures :all

    include Phase2Fixtures
    include PosFixtures
  end
end
