# frozen_string_literal: true

module Customers
  # Staff-initiated customer merge per ADR-023.
  #
  # Flattens existing aliases of the source onto the survivor, reassigns active
  # requests, tombstones the source, and audits — all in one transaction.
  class MergeCustomers
    Result = Data.define(
      :survivor,
      :source,
      :requests_reassigned_count,
      :aliases_repointed_ids,
      :replayed,
      :stored_value_transfer_ids
    )

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      source:,
      survivor:,
      actor:,
      reason:,
      idempotency_key:,
      store: nil,
      correlation_id: nil,
      expected_source_lock_version: nil,
      expected_survivor_lock_version: nil
    )
      @source = source
      @survivor = survivor
      @actor = actor
      @reason = reason.to_s.strip
      @idempotency_key = idempotency_key
      @store = store
      @correlation_id = correlation_id || SecureRandom.uuid_v7
      @expected_source_lock_version = expected_source_lock_version
      @expected_survivor_lock_version = expected_survivor_lock_version
    end

    def call
      raise Customers::Error, "actor is required" if @actor.blank?
      raise Customers::Error, "idempotency key is required" if @idempotency_key.blank?
      raise Customers::Error, "reason is required" if @reason.blank?
      raise Customers::Error, "source is required" if @source.blank?
      raise Customers::Error, "survivor is required" if @survivor.blank?

      payload = {
        source_customer_id: @source.id,
        survivor_customer_id: @survivor.id,
        reason: @reason
      }

      op = Idempotency::OperationService.begin!(
        source_id: @source.id,
        operation_type: "merge_customers",
        idempotency_key: @idempotency_key,
        payload: payload
      )

      if op.replayed
        survivor = Customer.find(op.operation.result_id)
        source = Customer.find(@source.id)
        return Result.new(
          survivor: survivor,
          source: source,
          requests_reassigned_count: op.operation.result_payload["requests_reassigned_count"].to_i,
          aliases_repointed_ids: Array(op.operation.result_payload["aliases_repointed_ids"]),
          replayed: true,
          stored_value_transfer_ids: Array(op.operation.result_payload["stored_value_transfer_ids"])
        )
      end

      begin
        result = nil
        Customer.transaction do
          # Lock source and survivor first (deterministic UUID order) so competing
          # merges that share either row cannot miss newly created aliases.
          primary = [ @source.id, @survivor.id ].uniq.sort.index_with { |id| Customer.lock.find(id) }
          source = primary.fetch(@source.id)
          survivor = primary.fetch(@survivor.id)

          validate_merge!(source, survivor)
          assert_lock_versions!(source, survivor)

          alias_ids = Customer.where(merged_into_customer_id: source.id).order(:id).pluck(:id)
          aliases = alias_ids.map { |id| Customer.lock.find(id) }

          aliases.each do |alias_customer|
            alias_customer.update!(merged_into_customer_id: survivor.id)
          end
          aliases_repointed_ids = aliases.map(&:id)

          requests_reassigned_count = Customers::ReassignActiveRequests.call(
            source: source,
            survivor: survivor
          )

          store = @store || Store.active.order(:name).first
          stored_value_transfer_ids = Customers::MergeStoredValueAccounts.call(
            source: source,
            survivor: survivor,
            actor: @actor,
            store: store,
            merge_idempotency_operation: op.operation,
            correlation_id: @correlation_id
          )

          source.update!(
            merged_into_customer_id: survivor.id,
            active: false
          )

          Audit::Recorder.record!(
            action: "customers.merge",
            outcome: "succeeded",
            actor_user: @actor,
            store: @store,
            subject: survivor,
            correlation_id: @correlation_id,
            after_values: {
              source_customer_id: source.id,
              survivor_customer_id: survivor.id,
              reason: @reason,
              aliases_repointed_count: aliases_repointed_ids.size,
              aliases_repointed_ids: aliases_repointed_ids.first(50),
              customer_requests_reassigned_count: requests_reassigned_count,
              stored_value_transfer_ids: stored_value_transfer_ids
            }
          )

          Idempotency::OperationService.complete!(
            op.operation,
            result_type: "Customer",
            result_id: survivor.id,
            result_payload: {
              requests_reassigned_count: requests_reassigned_count,
              aliases_repointed_ids: aliases_repointed_ids,
              stored_value_transfer_ids: stored_value_transfer_ids
            }
          )

          result = Result.new(
            survivor: survivor,
            source: source.reload,
            requests_reassigned_count: requests_reassigned_count,
            aliases_repointed_ids: aliases_repointed_ids,
            replayed: false,
            stored_value_transfer_ids: stored_value_transfer_ids
          )
        end
        result
      rescue Customers::Error, StoredValue::Error, ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError => e
        Idempotency::OperationService.fail!(op.operation, message: e.message)
        raise Customers::Error, e.message
      rescue Idempotency::OperationService::PayloadMismatchError
        raise
      end
    end

    private

    def validate_merge!(source, survivor)
      raise Customers::Error, "cannot merge a customer into itself" if source.id == survivor.id
      raise Customers::Error, "source customer is already merged" if source.merged?
      raise Customers::Error, "survivor must be a canonical customer" unless survivor.canonical?
      raise Customers::Error, "survivor must be active" unless survivor.active?
    end

    def assert_lock_versions!(source, survivor)
      if @expected_source_lock_version.present? && source.lock_version != @expected_source_lock_version.to_i
        raise ActiveRecord::StaleObjectError.new(source, "merge")
      end
      if @expected_survivor_lock_version.present? && survivor.lock_version != @expected_survivor_lock_version.to_i
        raise ActiveRecord::StaleObjectError.new(survivor, "merge")
      end
    end
  end
end
