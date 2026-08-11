# frozen_string_literal: true

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resource :session, only: %i[new create destroy]
  resource :store_selection, only: %i[new create]

  namespace :admin do
    resource :system_settings, only: %i[show edit update]
    resources :stores
    resources :gl_accounts do
      member { post :reactivate }
    end
    resources :tax_classes do
      member { post :reactivate }
    end
    resources :departments do
      member { post :reactivate }
    end
    resources :merchandise_classes do
      member { post :reactivate }
    end
    resources :merchandise_categories do
      member { post :reactivate }
    end
    resources :merchandise_conditions do
      member { post :reactivate }
    end
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
    resources :merchandise_imports, only: %i[new create] do
      collection { get :template }
    end
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
