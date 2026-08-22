# Pin npm packages by running ./bin/importmap

pin "application"
pin "admin_store_receipt_messages"
pin "pos"
pin "purchasing_ops"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
