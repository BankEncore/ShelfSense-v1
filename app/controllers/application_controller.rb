# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include SessionAuthentication
  include AuthorizesRequests

  allow_browser versions: :modern unless Rails.env.test?
  before_action :require_authentication
end
