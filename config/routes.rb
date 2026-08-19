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
    resources :store_taxes do
      member { post :reactivate }
    end
    resources :registers
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
    resources :tender_types do
      member { post :reactivate }
    end
    resource :inventory_reconciliation, only: %i[show], controller: "inventory_reconciliations"
  end

  namespace :pos do
    resources :transactions, only: %i[index show]
    get "register/enter", to: "enters#show", as: :register_enter
    post "register/enter", to: "enters#create"
    get "register", to: "workspaces#show", as: :register_workspace
    post "register/merchandise", to: "workspaces#merchandise"
    post "register/quantity", to: "workspaces#quantity"
    post "register/remove", to: "workspaces#remove"
    post "register/controlled_action", to: "workspaces#controlled_action"
    post "register/unlinked_return_lookup", to: "workspaces#unlinked_return_lookup"
    post "register/unlinked_return", to: "workspaces#unlinked_return"
    post "register/abandon_tender", to: "workspaces#abandon_tender"
    post "register/cancel", to: "workspaces#cancel"
    post "register/tender", to: "workspaces#tender"
    post "register/remove_tender", to: "workspaces#remove_tender"
    post "register/continue", to: "workspaces#continue"
    get "transactions/:transaction_id/return_items", to: "return_items#show", as: :transaction_return_items
    post "transactions/:transaction_id/return_items", to: "return_items#create"
    post "transactions/:transaction_id/complete", to: "workspaces#complete", as: :transaction_complete
    get "transactions/:id/completed", to: "completed_transactions#show", as: :completed_transaction
    post "register/close", to: "register_closes#create", as: :register_close
    get "sessions/:id/close", to: "session_closes#show", as: :session_close
    post "sessions/:id/close", to: "session_closes#create"
    post "sessions/:id/resume_sales", to: "session_closes#resume_sales", as: :session_resume_sales
    get "sessions/:id/closed", to: "closed_sessions#show", as: :session_closed
    post "reporting_periods/:id/finalize", to: "reporting_period_finalizations#create", as: :reporting_period_finalize
    get "reporting_periods/:id/z", to: "reporting_period_zs#show", as: :reporting_period_z
  end

  root "home#show"
end
