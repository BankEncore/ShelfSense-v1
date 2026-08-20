# frozen_string_literal: true

require "test_helper"

class PosEnterRegisterLegalNameTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    @register = Register.create!(store: @store, register_number: 1, name: "Front")
  end

  test "refuses enter when the store legal name is blank" do
    @store.update_columns(legal_name: nil)

    error = assert_raises(Pos::Error) do
      Pos::EnterRegister.call(
        store: @store.reload,
        register: @register,
        actor: @actor,
        opening_float_cents: 0
      )
    end
    assert_equal "This Store cannot use POS until its legal name is configured.", error.message
    assert_equal 0, PosSession.where(register: @register).count
  end
end
