# frozen_string_literal: true

require "test_helper"

class PosCompletedTransactionSearchTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    @context = pos_open_context(store: @store, actor: @actor)
    @session = @context[:session]
    @base_time = Time.utc(2026, 8, 18, 12, 0, 0)
  end

  test "no filters returns only current-store completed transactions newest first" do
    other_store = Store.create!(store_number: "2", code: "east", name: "East", timezone: "America/New_York", country_code: "US")
    other_context = pos_open_context(store: other_store, actor: @actor)
    older = insert_completed_transaction!(session: @session, receipt_sequence: 1, completed_at: @base_time, cashier_name: "Ada")
    newer = insert_completed_transaction!(session: @session, receipt_sequence: 2, completed_at: @base_time + 60, cashier_name: "Ada")
    insert_completed_transaction!(session: other_context[:session], receipt_sequence: 1, completed_at: @base_time + 120, cashier_name: "Ada")
    PosTransaction.create!(
      store: @store,
      register: @context[:register],
      pos_session: @session,
      reporting_period: @context[:period],
      cashier_user: @actor,
      status: "working",
      currency_code: "USD"
    )
    PosTransaction.create!(
      store: @store,
      register: @context[:register],
      pos_session: @session,
      reporting_period: @context[:period],
      cashier_user: @actor,
      status: "cancelled",
      cancelled_at: Time.current,
      currency_code: "USD"
    )

    result = Pos::CompletedTransactionSearch.call(store: @store)
    assert_equal [ newer.id, older.id ], result.records.map(&:id)
    assert_equal 2, result.total_count
    refute result.filtered
  end

  test "page size is 50 and invalid page is clamped" do
    51.times do |index|
      insert_completed_transaction!(
        session: @session,
        receipt_sequence: index + 1,
        completed_at: @base_time + index
      )
    end

    first = Pos::CompletedTransactionSearch.call(store: @store, page: 1)
    assert_equal 50, first.records.size
    assert_equal 51, first.total_count
    assert_equal 2, first.total_pages

    second = Pos::CompletedTransactionSearch.call(store: @store, page: 2)
    assert_equal 1, second.records.size

    clamped = Pos::CompletedTransactionSearch.call(store: @store, page: "nope")
    assert_equal 1, clamped.page
    overflow = Pos::CompletedTransactionSearch.call(store: @store, page: 99)
    assert_equal 2, overflow.page
  end

  test "exact transaction_reference ignores leftover register sequence and date" do
    match = insert_completed_transaction!(
      session: @session,
      receipt_sequence: 10,
      completed_at: @base_time,
      business_date: Date.new(2026, 8, 18)
    )
    insert_completed_transaction!(
      session: @session,
      receipt_sequence: 11,
      completed_at: @base_time + 10,
      business_date: Date.new(2026, 8, 19)
    )

    result = Pos::CompletedTransactionSearch.call(
      store: @store,
      transaction_reference: "  #{match.transaction_reference.downcase}  ",
      register_id: SecureRandom.uuid_v7,
      receipt_sequence: "11",
      business_date: "2026-08-19"
    )
    assert_equal [ match.id ], result.records.map(&:id)
    assert result.filtered
  end

  test "register and receipt_sequence and business_date AND together" do
    second = pos_open_context(store: @store, actor: @actor, register: Register.create!(store: @store, register_number: 2, name: "Back"))
    wanted = insert_completed_transaction!(
      session: second[:session],
      receipt_sequence: 7,
      completed_at: @base_time,
      business_date: Date.new(2026, 8, 18)
    )
    insert_completed_transaction!(
      session: second[:session],
      receipt_sequence: 8,
      completed_at: @base_time + 10,
      business_date: Date.new(2026, 8, 18)
    )
    insert_completed_transaction!(
      session: @session,
      receipt_sequence: 7,
      completed_at: @base_time + 20,
      business_date: Date.new(2026, 8, 18)
    )

    result = Pos::CompletedTransactionSearch.call(
      store: @store,
      register_id: second[:register].id,
      receipt_sequence: "0000007",
      business_date: "2026-08-18"
    )
    assert_equal [ wanted.id ], result.records.map(&:id)
  end

  test "receipt_sequence without register matches across the store" do
    second = pos_open_context(store: @store, actor: @actor, register: Register.create!(store: @store, register_number: 2, name: "Back"))
    first = insert_completed_transaction!(session: @session, receipt_sequence: 4, completed_at: @base_time)
    other = insert_completed_transaction!(session: second[:session], receipt_sequence: 4, completed_at: @base_time + 30)

    result = Pos::CompletedTransactionSearch.call(store: @store, receipt_sequence: "4")
    assert_equal [ other.id, first.id ], result.records.map(&:id)
  end

  test "inactive register remains a valid filter and foreign register is empty" do
    second = pos_open_context(store: @store, actor: @actor, register: Register.create!(store: @store, register_number: 2, name: "Back"))
    sale = insert_completed_transaction!(session: second[:session], receipt_sequence: 1, completed_at: @base_time)
    second[:register].update_column(:active, false)

    found = Pos::CompletedTransactionSearch.call(store: @store, register_id: second[:register].id)
    assert_equal [ sale.id ], found.records.map(&:id)

    east = Store.create!(store_number: "9", code: "west", name: "West", timezone: "America/New_York", country_code: "US")
    foreign = Register.create!(store: east, register_number: 1, name: "Foreign")
    empty = Pos::CompletedTransactionSearch.call(store: @store, register_id: foreign.id)
    assert_equal 0, empty.total_count
  end

  test "invalid date and sequence fail safely" do
    insert_completed_transaction!(session: @session, receipt_sequence: 1, completed_at: @base_time)
    assert_equal 0, Pos::CompletedTransactionSearch.call(store: @store, business_date: "18/08/2026").total_count
    assert_equal 0, Pos::CompletedTransactionSearch.call(store: @store, receipt_sequence: "abc").total_count
    assert_equal 0, Pos::CompletedTransactionSearch.call(store: @store, receipt_sequence: "0").total_count
  end
end
