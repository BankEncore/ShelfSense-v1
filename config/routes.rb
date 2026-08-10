# frozen_string_literal: true

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resource :session, only: %i[new create destroy]
  resource :store_selection, only: %i[new create]

  namespace :admin do
    resource :system_settings, only: %i[show edit update]
    resources :stores
    resources :users do
      member do
        post :deactivate
        post :reset_password
      end
    end
    resources :roles
    resources :role_assignments, only: %i[index new create destroy]
    resources :workstations
    resources :audit_events, only: %i[index show]
  end

  root "home#show"
end
