# frozen_string_literal: true

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resource :session, only: %i[new create destroy]
  resource :store_selection, only: %i[new create]

  namespace :admin do
    resource :system_settings, only: %i[show edit update]
    resources :stores
    resources :gl_accounts
    resources :tax_classes
    resources :departments
    resources :merchandise_classes
    resources :merchandise_categories
    resources :merchandise_conditions
    resources :products do
      member do
        post :discontinue
      end
      resources :product_variants, shallow: true do
        member do
          post :discontinue
        end
      end
    end
    resources :merchandise_lookups, only: %i[new create]
    resources :merchandise_imports, only: %i[new create]
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
