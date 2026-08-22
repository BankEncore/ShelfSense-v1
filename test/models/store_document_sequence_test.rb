# frozen_string_literal: true

require "test_helper"

class StoreDocumentSequenceTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
  end

  test "allocates monotonic numbers per store and kind" do
    assert_equal 1, StoreDocumentSequence.next_number!(store: @store, document_kind: "customer_request")
    assert_equal 2, StoreDocumentSequence.next_number!(store: @store, document_kind: "customer_request")
    assert_equal 1, StoreDocumentSequence.next_number!(store: @store, document_kind: "order")
  end
end
