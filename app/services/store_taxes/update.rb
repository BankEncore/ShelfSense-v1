# frozen_string_literal: true

module StoreTaxes
  class Update
    class Error < StandardError; end

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(store_tax:, actor:, expected_lock_version:, name: nil, rate_percent: nil, calculation_order: nil, code: nil, applies_by_tax_class_id: {})
      @store_tax = store_tax
      @actor = actor
      @expected_lock_version = expected_lock_version
      @name = name
      @rate_percent = rate_percent
      @calculation_order = calculation_order
      @code = code
      @applies_by_tax_class_id = applies_by_tax_class_id || {}
    end

    def call
      StoreTax.transaction do
        @store_tax.lock_version = @expected_lock_version
        attrs = {
          name: @name,
          rate_percent: @rate_percent,
          calculation_order: @calculation_order
        }.compact
        attrs[:code] = @code unless @code.nil?
        @store_tax.assign_attributes(attrs)
        raise Error, @store_tax.errors.full_messages.to_sentence unless @store_tax.valid?

        @store_tax.save!
        apply_rules!
        Audit::Recorder.record!(
          action: "store_taxes.update",
          outcome: "succeeded",
          actor_user: @actor,
          actor_label: @actor.display_name,
          store: @store_tax.store,
          subject: @store_tax
        )
      end
      @store_tax
    rescue ActiveRecord::StaleObjectError
      raise Error, "This record was changed by someone else. Reload and try again."
    rescue ActiveRecord::RecordInvalid => e
      raise Error, e.message
    end

    private

    def apply_rules!
      @applies_by_tax_class_id.each do |tax_class_id, applies|
        next if applies.nil? || applies == ""

        rule = @store_tax.store_tax_rules.find_by!(tax_class_id: tax_class_id)
        rule.update!(applies: ActiveModel::Type::Boolean.new.cast(applies))
      end
    end
  end
end
