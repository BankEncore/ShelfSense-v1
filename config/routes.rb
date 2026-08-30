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
    resources :product_forms, except: %i[new create] do
      member { post :reactivate }
    end
    resources :subject_schemes, except: %i[new create destroy] do
      resources :subject_headings do
        member { post :reactivate }
        collection do
          get :import
          post :import, action: :process_import
        end
      end
    end
    resources :products do
      member do
        post :discontinue
        post :reactivate
        post :refresh_bibliography
        get :bibliographic_review
        post :apply_bibliography
      end
      resources :product_variants, shallow: true do
        member do
          post :discontinue
        end
        resources :supplier_variant_sources, only: %i[new create]
      end
    end
    resources :product_catalog_searches, only: %i[new create]
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
    resources :suppliers do
      member { post :reactivate }
      resources :supplier_variant_sources, shallow: true, except: :index do
        member { post :reactivate }
        resources :store_supplier_source_preferences, only: %i[create destroy]
      end
    end
    resources :customers do
      member do
        post :reactivate
        get :merge_review
        post :merge
      end
      collection { get :duplicate_check }
      resources :stored_value_adjustments, only: %i[new create]
    end
    resources :stored_value_adjustment_reasons do
      member { post :reactivate }
    end
    resources :stored_value_transfers, only: %i[new create]
    resources :gift_card_programs do
      member { post :reactivate }
    end
    resource :cash_safe, only: %i[show new create], controller: "cash_safes"
    resource :cash_safe_reconciliation, only: %i[new create], controller: "cash_safe_reconciliations"
    resources :cash_deposits, only: %i[index new create show] do
      member { post :reverse }
    end
    resource :cash_store_day, only: :show, controller: "cash_store_days"
    resources :gift_cards, only: %i[index show] do
      collection do
        get :inquiry
        post :inquiry, action: :resolve_inquiry
      end
      member do
        post :suspend
        post :reinstate
        get :replace
        post :replace, action: :create_replacement
        get :credential
        get :associate
        patch :associate, action: :update_association
        get :print_recovery
        post :print_recovery, action: :create_print_recovery
      end
      resources :stored_value_adjustments, only: %i[new create], controller: "gift_card_adjustments"
    end
    resource :stored_value_report, only: :show
    resources :customer_requests, only: %i[index show new create] do
      collection do
        get :customer_lookup
        get :merchandise_lookup
      end
      member { post :cancel }
    end
    resources :orders, only: %i[index show new create]
    resource :purchasing, only: %i[show], controller: "purchasing"
    resources :purchase_orders, only: %i[index show] do
      member do
        post "lines/:line_id/cancel", action: :cancel_line, as: :cancel_line
        patch "lines/:line_id/acknowledge", action: :acknowledge_line, as: :acknowledge_line
      end
    end
    resources :purchase_receipts, only: %i[index show] do
      member do
        post :reverse
        post "lines/:line_id/reverse", action: :reverse_line, as: :reverse_line
        post "lines/:line_id/correct_cost", action: :correct_cost, as: :correct_cost
      end
    end
    resource :inventory_reconciliation, only: %i[show], controller: "inventory_reconciliations"
  end

  namespace :ops do
    get "location", to: "locations#show", as: :location
    post "location/requests/:id/confirm", to: "locations#confirm", as: :location_confirm
    post "location/requests/:id/not_located", to: "locations#not_located", as: :location_not_located
    get "draft_pos", to: "draft_pos#index", as: :draft_pos
    get "purchase_orders/:id", to: "draft_pos#show", as: :purchase_order
    post "purchase_orders/:id/lines", to: "draft_pos#add_line", as: :purchase_order_add_line
    patch "purchase_orders/:id/lines/:line_id", to: "draft_pos#update_line", as: :purchase_order_update_line
    post "purchase_orders/:id/generate", to: "draft_pos#generate", as: :purchase_order_generate
    post "purchase_orders/:id/send", to: "draft_pos#send_po", as: :purchase_order_send
    post "purchase_orders/:id/return_to_draft", to: "draft_pos#return_to_draft", as: :purchase_order_return_to_draft

    get "receiving", to: "receiving#index", as: :receiving_index
    post "receiving", to: "receiving#create", as: :receiving_create
    get "receiving/:id", to: "receiving#show", as: :receiving
    get "receiving/:id/line_lookup", to: "receiving#line_lookup", as: :receiving_line_lookup
    patch "receiving/:id", to: "receiving#update", as: :receiving_update
    post "receiving/:id/lines", to: "receiving#add_line", as: :receiving_add_line
    patch "receiving/:id/lines/:line_id", to: "receiving#update_line", as: :receiving_update_line
    get "receiving/:id/review", to: "receiving#review", as: :receiving_review
    post "receiving/:id/post", to: "receiving#post", as: :receiving_post
    post "receiving/:id/reverse", to: "receiving#reverse", as: :receiving_reverse
    post "receiving/:id/lines/:line_id/reverse", to: "receiving#reverse_line", as: :receiving_reverse_line
    post "receiving/:id/lines/:line_id/correct_cost", to: "receiving#correct_cost", as: :receiving_correct_cost
  end

  get "/pos", to: "pos/homes#show", as: :pos

  namespace :pos do
    get "switch_register", to: "preferred_registers#new", as: :switch_register
    post "preferred_register", to: "preferred_registers#create", as: :preferred_register
    get "x_report", to: "x_reports#show", as: :x_report
    get "sessions/:id/x_report", to: "x_reports#show", as: :session_x_report
    get "active_sessions", to: "active_sessions#index", as: :active_sessions
    get "till_activity", to: "till_activities#index", as: :till_activity
    get "sessions/:id/details", to: "session_details#show", as: :session_details
    resources :cash_operations, only: :show do
      member { post :reversal }
    end
    get "reports", to: "reports#index", as: :reports
    get "report_prints/:scope(/:id)", to: "report_prints#show", as: :report_print
    get "z_status", to: "reporting_period_statuses#show", as: :z_status
    get "reporting_periods/:id/status", to: "reporting_period_statuses#show", as: :reporting_period_status
    get "reporting_periods/:id/finalize", to: "reporting_period_finalizations#new", as: :reporting_period_finalize_confirm
    post "reporting_periods/:id/finalize", to: "reporting_period_finalizations#create", as: :reporting_period_finalize
    get "reporting_periods/:id/z", to: "reporting_period_zs#show", as: :reporting_period_z

    resources :transactions, only: %i[index show]
    resource :stored_value_inquiry, only: :show, controller: "stored_value_inquiries" do
      post :exact_number
      post :store_credit
      post :admin_prefix_last_four
    end
    resource :customer_summary, only: :show, controller: "customer_summaries"
    get "pickup_queue", to: "pickup_queues#index", as: :pickup_queue
    get "register/enter", to: "enters#show", as: :register_enter
    post "register/enter", to: "enters#create"
    resources :cash_outs, only: %i[new create show] do
      collection { post :lookup }
      member { post :reverse }
    end
    resources :cash_paid_ins, only: %i[new create]
    resources :cash_paid_outs, only: %i[new create]
    resources :cash_drops, only: %i[new create]
    resources :cash_replenishments, only: %i[new create]
    get "register", to: "workspaces#show", as: :register_workspace
    get "register/merchandise_search", to: "workspaces#search", as: :register_merchandise_search
    get "register/merchandise_resolve", to: "workspaces#resolve", as: :register_merchandise_resolve
    get "register/pickup_search", to: "workspaces#pickup_search", as: :register_pickup_search
    post "register/merchandise", to: "workspaces#merchandise"
    post "register/pickup", to: "workspaces#pickup"
    post "register/open_price", to: "workspaces#open_price"
    post "register/quantity", to: "workspaces#quantity"
    post "register/remove", to: "workspaces#remove"
    post "register/controlled_action", to: "workspaces#controlled_action"
    get "register/linked_return_lookup", to: "workspaces#linked_return_lookup", as: :register_linked_return_lookup
    post "register/linked_return", to: "workspaces#linked_return"
    post "register/unlinked_return_lookup", to: "workspaces#unlinked_return_lookup"
    post "register/unlinked_return", to: "workspaces#unlinked_return"
    post "register/abandon_tender", to: "workspaces#abandon_tender"
    post "register/cancel", to: "workspaces#cancel"
    post "register/tender", to: "workspaces#tender"
    post "register/stored_value_issuance", to: "workspaces#stored_value_issuance"
    post "register/remove_stored_value_issuance", to: "workspaces#remove_stored_value_issuance"
    post "register/attach_customer", to: "workspaces#attach_customer"
    post "register/detach_customer", to: "workspaces#detach_customer"
    post "register/quick_customer", to: "workspaces#quick_customer", as: :register_quick_customer
    get "register/customer_search", to: "workspaces#customer_search", as: :register_customer_search
    post "register/remove_tender", to: "workspaces#remove_tender"
    post "register/replace_tender", to: "workspaces#replace_tender"
    post "register/continue", to: "workspaces#continue"
    get "transactions/:transaction_id/return_items", to: "return_items#show", as: :transaction_return_items
    post "transactions/:transaction_id/return_items", to: "return_items#create"
    get "transactions/:transaction_id/post_void", to: "post_voids#show", as: :transaction_post_void
    post "transactions/:transaction_id/post_void", to: "post_voids#create"
    post "transactions/:transaction_id/complete", to: "workspaces#complete", as: :transaction_complete
    get "transactions/:id/completed", to: "completed_transactions#show", as: :completed_transaction
    post "register/close", to: "register_closes#create", as: :register_close
    get "sessions/:id/close", to: "session_closes#show", as: :session_close
    post "sessions/:id/close", to: "session_closes#create"
    post "sessions/:id/resume_sales", to: "session_closes#resume_sales", as: :session_resume_sales
    get "sessions/:id/closed", to: "closed_sessions#show", as: :session_closed
  end

  root "home#show"
end
