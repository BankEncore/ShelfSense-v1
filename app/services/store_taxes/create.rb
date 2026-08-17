# frozen_string_literal: true

module StoreTaxes
  class Create
    class Error < StandardError; end

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(store:, actor:, code: nil, name:, rate_percent:, calculation_order: 0, applies_by_tax_class_id: {})
      @store = store
      @actor = actor
      @code = code
      @name = name
      @rate_percent = rate_percent
      @calculation_order = calculation_order
      @applies_by_tax_class_id = applies_by_tax_class_id || {}
    end

    def call
      StoreTaxes::Support.authorize!(@actor, @store, "store_taxes.create")

      store_tax = StoreTax.new(
        store: @store,
        code: @code,
        name: @name,
        rate_percent: @rate_percent,
        calculation_order: @calculation_order
      )
      raise Error, store_tax.errors.full_messages.to_sentence unless store_tax.valid?

      StoreTax.transaction do
        store_tax.save!
        StoreTaxes::EnsureRules.for_store_tax(store_tax)
        apply_initial_rules!(store_tax)
        Audit::Recorder.record!(
          action: "store_taxes.create",
          outcome: "succeeded",
          actor_user: @actor,
          actor_label: @actor.display_name,
          store: @store,
          subject: store_tax,
          after_values: { code: store_tax.code, name: store_tax.name, rate_percent: store_tax.rate_percent_display }
        )
      end
      store_tax
    rescue ActiveRecord::RecordInvalid => e
      raise Error, e.message
    end

    private

    def apply_initial_rules!(store_tax)
      @applies_by_tax_class_id.each do |tax_class_id, applies|
        next if applies.nil? || applies == ""

        rule = store_tax.store_tax_rules.find_by!(tax_class_id: tax_class_id)
        rule.update!(applies: ActiveModel::Type::Boolean.new.cast(applies))
      end
    end
  end
end
