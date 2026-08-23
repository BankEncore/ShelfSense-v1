# frozen_string_literal: true

class StoreSelectionsController < ApplicationController
  def new
    @stores = accessible_stores
    @return_to = safe_internal_return_path(params[:return_to])
  end

  def create
    store = accessible_stores.find_by(id: params.require(:store_id))
    unless store
      redirect_to new_store_selection_path(return_to: params[:return_to]), alert: "That store is not available."
      return
    end

    session[:current_store_id] = store.id
    session.delete(:pos_register_id)
    redirect_to safe_internal_return_path(params[:return_to]) || root_path, notice: "Working in #{store.name}."
  end

  private

  # Only same-origin relative paths (including query string). Blocks open redirects.
  def safe_internal_return_path(value)
    value = value.to_s
    return if value.blank?

    uri = URI.parse(value)
    return unless uri.scheme.nil? && uri.host.nil?
    return unless uri.path&.start_with?("/")
    return if uri.path.start_with?("//")

    value
  rescue URI::InvalidURIError
    nil
  end
end
