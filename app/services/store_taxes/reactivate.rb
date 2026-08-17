# frozen_string_literal: true

module StoreTaxes
  class Reactivate
    class Error < StandardError; end

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(store_tax:, actor:, expected_lock_version: nil)
      @store_tax = store_tax
      @actor = actor
      @expected_lock_version = expected_lock_version
    end

    def call
      StoreTaxes::Support.authorize!(@actor, @store_tax.store, "store_taxes.deactivate")

      Configuration::Reactivate.call(
        record: @store_tax,
        actor: @actor,
        lock_version: @expected_lock_version,
        store: @store_tax.store,
        audit_action: "store_taxes.reactivate"
      )
      StoreTaxes::EnsureRules.for_store_tax(@store_tax.reload)
      @store_tax
    rescue ActiveRecord::StaleObjectError
      raise Error, "This record was changed by someone else. Reload and try again."
    rescue Configuration::Reactivate::Error => e
      raise Error, e.message
    end
  end
end
