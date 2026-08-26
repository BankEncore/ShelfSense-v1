# frozen_string_literal: true

module Admin
  class CashStoreDaysController < BaseController
    before_action -> { require_permission!("pos.sessions.view") }
    before_action :ensure_store_selected

    def show
      @business_date = parse_business_date
      @report = Cash::StoreDayReport.for(store: current_store, business_date: @business_date)
      @safe = Cash::Locations.safe_for!(current_store)
      @dit = Cash::Locations.deposit_in_transit_for!(current_store)
    end

    private

    def parse_business_date
      raw = params[:business_date].presence
      return BusinessDate.for_store(current_store) if raw.blank?

      Date.iso8601(raw)
    rescue Date::Error
      BusinessDate.for_store(current_store)
    end

    def ensure_store_selected
      return if current_store

      redirect_to new_store_selection_path, alert: "Select a store."
    end
  end
end
