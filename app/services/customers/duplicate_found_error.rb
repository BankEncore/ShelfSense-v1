# frozen_string_literal: true

module Customers
  class DuplicateFoundError < Error
    attr_reader :suggestions

    def initialize(suggestions)
      @suggestions = Array(suggestions)
      super("Possible duplicate customers found.")
    end
  end
end
