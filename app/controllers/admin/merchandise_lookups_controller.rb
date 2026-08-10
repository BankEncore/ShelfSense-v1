# frozen_string_literal: true

module Admin
  class MerchandiseLookupsController < BaseController
    before_action -> { require_permission!("merchandise.lookup") }

    def new
      @raw = nil
      @result = nil
    end

    def create
      @raw = params.require(:lookup).permit(:raw)[:raw]
      @result = Identifiers::Lookup.call(@raw)
      render :new
    rescue ActionController::ParameterMissing
      @raw = nil
      @result = Identifiers::Lookup::Result.new(status: :invalid, message: "Identifier is required")
      render :new, status: :unprocessable_entity
    end
  end
end
