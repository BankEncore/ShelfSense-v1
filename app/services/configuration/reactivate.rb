# frozen_string_literal: true

module Configuration
  class Reactivate
    class Error < StandardError; end

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(record:, actor:, lock_version: nil, store: nil, audit_action:)
      @record = record
      @actor = actor
      @lock_version = lock_version
      @store = store
      @audit_action = audit_action
    end

    def call
      raise Error, "record is already active" if @record.active?

      blockers = @record.reactivation_blockers
      raise Error, blockers.to_sentence if blockers.any?

      @record.class.transaction do
        @record.lock_version = @lock_version unless @lock_version.nil?
        @record.update!(active: true)
        StoreTaxes::EnsureRules.for_tax_class(@record) if @record.is_a?(TaxClass)
        Audit::Recorder.record!(
          action: @audit_action,
          outcome: "succeeded",
          actor_user: @actor,
          actor_label: @actor.display_name,
          store: @store,
          subject: @record,
          before_values: { active: false },
          after_values: { active: true }
        )
      end
      @record
    rescue ActiveRecord::RecordInvalid => e
      raise Error, e.message
    end
  end
end
