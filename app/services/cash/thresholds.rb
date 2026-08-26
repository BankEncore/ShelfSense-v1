# frozen_string_literal: true

module Cash
  class Thresholds
    def self.note_cents(store)
      coalesce(store.cash_variance_note_threshold_cents, settings.cash_variance_note_threshold_cents)
    end

    def self.approval_cents(store)
      coalesce(store.cash_variance_approval_threshold_cents, settings.cash_variance_approval_threshold_cents)
    end

    def self.paid_out_cents(store)
      coalesce(store.cash_paid_out_approval_threshold_cents, settings.cash_paid_out_approval_threshold_cents)
    end

    def self.settings
      SystemSettings.current
    end

    def self.coalesce(store_value, org_value)
      store_value.nil? ? org_value.to_i : store_value.to_i
    end
    private_class_method :settings, :coalesce
  end
end
