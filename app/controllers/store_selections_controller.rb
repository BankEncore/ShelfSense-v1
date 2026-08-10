# frozen_string_literal: true

class StoreSelectionsController < ApplicationController
  def new
    @stores = accessible_stores
  end

  def create
    store = accessible_stores.find_by(id: params.require(:store_id))
    unless store
      redirect_to new_store_selection_path, alert: "That store is not available."
      return
    end

    session[:current_store_id] = store.id
    redirect_to root_path, notice: "Working in #{store.name}."
  end
end
