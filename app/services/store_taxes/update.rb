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
      StoreTaxes::Support.authorize!(@actor, @store_tax.store, "store_taxes.update")

      StoreTax.transaction do
        store_tax = StoreTax.lock.find(@store_tax.id)
        if store_tax.lock_version != @expected_lock_version.to_i
          raise Error, "This record was changed by someone else. Reload and try again."
        end

        before = snapshot(store_tax)
        assign_parent!(store_tax)
        raise Error, store_tax.errors.full_messages.to_sentence unless store_tax.valid?

        rules_changed = apply_rules!(store_tax)
        parent_changed = store_tax.has_changes_to_save?
        if parent_changed || rules_changed
          store_tax.updated_at = Time.current unless parent_changed
          store_tax.save!
          Audit::Recorder.record!(
            action: "store_taxes.update",
            outcome: "succeeded",
            actor_user: @actor,
            actor_label: @actor.display_name,
            store: store_tax.store,
            subject: store_tax,
            before_values: before,
            after_values: snapshot(store_tax.reload)
          )
        end
        @store_tax = store_tax
      end
      @store_tax
    rescue ActiveRecord::StaleObjectError
      raise Error, "This record was changed by someone else. Reload and try again."
    rescue ActiveRecord::RecordInvalid => e
      raise Error, e.message
    end

    private

    def assign_parent!(store_tax)
      attrs = {
        name: @name,
        rate_percent: @rate_percent,
        calculation_order: @calculation_order
      }.compact
      attrs[:code] = @code unless @code.nil?
      store_tax.assign_attributes(attrs)
    end

    def apply_rules!(store_tax)
      changed = false
      @applies_by_tax_class_id.each do |tax_class_id, applies|
        next if applies.nil? || applies == ""

        rule = store_tax.store_tax_rules.find_by!(tax_class_id: tax_class_id)
        new_value = ActiveModel::Type::Boolean.new.cast(applies)
        next if rule.applies == new_value

        rule.update!(applies: new_value)
        changed = true
      end
      changed
    end

    def snapshot(store_tax)
      applies = store_tax.store_tax_rules.includes(:tax_class).each_with_object({}) do |rule, memo|
        memo[rule.tax_class.code] = rule.applies
      end
      {
        "code" => store_tax.code,
        "name" => store_tax.name,
        "rate_percent" => store_tax.rate_percent_display,
        "calculation_order" => store_tax.calculation_order,
        "applies" => applies
      }
    end
  end
end
