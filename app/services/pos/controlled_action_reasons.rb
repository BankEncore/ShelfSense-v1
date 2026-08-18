# frozen_string_literal: true

module Pos
  module ControlledActionReasons
    module_function

    CATALOGS = {
      "price_override" => {
        "shelf_price_mismatch" => "Shelf price mismatch",
        "damaged" => "Damaged",
        "price_match" => "Price match",
        "customer_service" => "Customer service",
        "manager_discretion" => "Manager discretion",
        "other" => "Other"
      },
      "line_discount" => {
        "damaged" => "Damaged",
        "customer_service" => "Customer service",
        "manager_discretion" => "Manager discretion",
        "other" => "Other"
      },
      "tax_class_override" => {
        "classification_correction" => "Classification correction",
        "tax_configuration_exception" => "Tax configuration exception",
        "manager_discretion" => "Manager discretion",
        "other" => "Other"
      }
    }.freeze

    def name_for!(action_type, code)
      catalog = CATALOGS.fetch(action_type) { raise Pos::Error, "unknown controlled action" }
      catalog.fetch(code) { raise Pos::Error, "reason is not valid" }
    end

    def require_note?(code)
      code == "other"
    end
  end
end
