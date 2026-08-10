# frozen_string_literal: true

class HomeController < ApplicationController
  def show
    if accessible_stores.many? && current_store.nil?
      redirect_to new_store_selection_path
    end
  end
end
