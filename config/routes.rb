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
        post :reactivate
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
    resources :inventory_balances, only: %i[index show], path: "inventory" do
      member do
        get :history
        get :rebuild
        post :rebuild, action: :confirm_rebuild
      end
    end
    resources :inventory_adjustments, only: %i[show new create] do
      collection do
        post :preview
      end
      member do
        get :reverse
        post :reverse, action: :confirm_reverse
      end
    end
    resources :adjustment_reasons do
      member { post :reactivate }
    end
    resource :inventory_reconciliation, only: %i[show], controller: "inventory_reconciliations"
  end

  root "home#show"
end
