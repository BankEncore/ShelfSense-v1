# frozen_string_literal: true

require "test_helper"

class PosEnterRegisterTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    @register = Register.create!(store: @store, register_number: 1, name: "Front")
  end

  test "opens a period session and working transaction" do
    result = Pos::EnterRegister.call(
      store: @store,
      register: @register,
      actor: @actor,
      opening_float_cents: 5000
    )
    assert result.session.open?
    assert_equal 5000, result.session.opening_float_cents
    assert result.transaction.working?
    assert_equal @actor.id, result.session.cashier_user_id
  end

  test "resumes the actor's open session without changing opening float" do
    first = Pos::EnterRegister.call(
      store: @store,
      register: @register,
      actor: @actor,
      opening_float_cents: 2500
    )
    second = Pos::EnterRegister.call(
      store: @store,
      register: @register,
      actor: @actor,
      opening_float_cents: 9999
    )
    assert_equal first.session.id, second.session.id
    assert_equal first.transaction.id, second.transaction.id
    assert_equal 2500, second.session.reload.opening_float_cents
  end

  test "denies a second cashier on an occupied register" do
    Pos::EnterRegister.call(
      store: @store,
      register: @register,
      actor: @actor,
      opening_float_cents: 0
    )
    other = pos_transacting_user(store: @store, assigned_by: @actor, username: "other_enter")
    assert_raises(Pos::Denied) do
      Pos::EnterRegister.call(
        store: @store,
        register: @register,
        actor: other,
        opening_float_cents: 0
      )
    end
  end

  test "requires opening float when creating a session" do
    error = assert_raises(Pos::Error) do
      Pos::EnterRegister.call(
        store: @store,
        register: @register,
        actor: @actor,
        opening_float_cents: nil
      )
    end
    assert_match(/opening float is required/, error.message)
    assert_equal 0, PosSession.where(register: @register).count
  end

  test "rejects a confirmed business date that no longer matches the store calendar" do
    now = Time.current
    confirmed = BusinessDate.for_store(@store, at: now)

    travel_to now + 1.day do
      error = assert_raises(Pos::Error) do
        Pos::EnterRegister.call(
          store: @store,
          register: @register,
          actor: @actor,
          opening_float_cents: 0,
          business_date: confirmed
        )
      end
      assert_match(/business date must match/, error.message)
      assert_equal 0, PosReportingPeriod.where(register: @register).count
    end
  end

  test "opens a period when the confirmed business date matches the store calendar" do
    confirmed = BusinessDate.for_store(@store)
    result = Pos::EnterRegister.call(
      store: @store,
      register: @register,
      actor: @actor,
      opening_float_cents: 0,
      business_date: confirmed
    )
    assert_equal confirmed, result.session.reporting_period.business_date
  end

  test "rejects a confirmed date that does not match an already open period" do
    Pos::OpenReportingPeriod.call(store: @store, register: @register, actor: @actor)
    error = assert_raises(Pos::Error) do
      Pos::EnterRegister.call(
        store: @store,
        register: @register,
        actor: @actor,
        opening_float_cents: 0,
        business_date: BusinessDate.for_store(@store) - 1.day
      )
    end
    assert_match(/already open on business date/, error.message)
    assert_equal 0, PosSession.where(register: @register).count
  end

  test "open gate is occupied for a different cashier" do
    Pos::EnterRegister.call(
      store: @store,
      register: @register,
      actor: @actor,
      opening_float_cents: 0
    )
    other = pos_transacting_user(store: @store, assigned_by: @actor, username: "other_gate")
    gate = Pos::OpenGate.for(store: @store, register: @register, actor: other)
    assert gate.occupied?
    assert_not gate.enterable?
    assert_equal @actor.id, gate.occupier.id
  end
end
