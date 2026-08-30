# frozen_string_literal: true

module Pos
  class ReplaceTender
    Result = Data.define(:transaction, :tender, :operation, :requested_cents, :applied_cents, :capped, :replayed)

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      transaction:, tender:, actor:, operation_id:, expected_lock_version:,
      amount_cents:, amount_presented_cents: nil, external_reference: nil
    )
      @transaction = transaction
      @tender = tender
      @actor = actor
      @operation_id = operation_id
      @expected_lock_version = expected_lock_version
      @amount_cents = amount_cents.to_i
      @amount_presented_cents = amount_presented_cents.presence&.to_i
      @external_reference = external_reference.to_s.strip.presence
    end

    def call
      lease = nil
      authorize!
      refuse_card!(@tender)

      lease = Pos::OperationLease.begin!(
        register_id: @transaction.register_id,
        operation_id: @operation_id,
        command_payload: command_payload,
        store_id: @transaction.store_id,
        pos_transaction_id: @transaction.id,
        command_type: PosOperation::REPLACE_WORKING_TENDER_COMMAND_TYPE
      )
      return replay_result(lease.operation) if lease.replayed

      result = nil
      PosTransaction.transaction do
        operation = PosOperation.lock.find(lease.operation.id)
        transaction = Pos::Support.lock_working_transaction!(@transaction, @expected_lock_version)
        original = transaction.pos_tenders.find(@tender.id)
        refuse_card!(original)

        outcome =
          if original.stored_value?
            replace_stored_value!(transaction, original)
          else
            replace_ordinary!(transaction, original)
          end

        Pos::Support.renumber_tenders!(transaction)
        Pos::Support.touch_working_transaction!(transaction)
        Audit::Recorder.record!(
          action: "pos.working_tender.replaced",
          outcome: "succeeded",
          actor_user: @actor,
          actor_label: @actor.display_name,
          store: transaction.store,
          register: transaction.register,
          subject: outcome.fetch(:replacement),
          before_values: outcome.fetch(:before),
          after_values: audit_snapshot(outcome.fetch(:replacement)),
          metadata: outcome.fetch(:metadata)
        )
        Pos::CompleteWorkingOperation.call(
          operation: operation,
          fact_type: PosOperation::REPLACE_WORKING_TENDER_FACT_TYPE,
          facts: {
            replaced_tender_id: original.id,
            replacement_tender_id: outcome.fetch(:replacement).id,
            requested_cents: @amount_cents,
            applied_cents: outcome.fetch(:applied_cents),
            capped: outcome.fetch(:capped)
          }
        )
        result = Result.new(
          transaction: transaction,
          tender: outcome.fetch(:replacement),
          operation: operation,
          requested_cents: @amount_cents,
          applied_cents: outcome.fetch(:applied_cents),
          capped: outcome.fetch(:capped),
          replayed: false
        )
      end
      result
    rescue Pos::PayloadMismatch, Pos::OperationLease::Error
      raise
    rescue GiftCards::Error => e
      Pos::OperationLease.fail!(lease.operation) if lease&.operation&.reload&.status == "in_flight"
      raise Pos::Error, e.message
    rescue StandardError
      Pos::OperationLease.fail!(lease.operation) if lease&.operation&.reload&.status == "in_flight"
      raise
    end

    private

    def authorize!
      Pos::Support.authorize!(@actor, @transaction.store)
      Pos::Support.require_active_context!(@transaction.store, @transaction.register)
      Pos::Support.require_transaction_cashier!(@actor, @transaction)
    end

    def refuse_card!(tender)
      return unless tender.behavioral_category == "card"

      raise Pos::Error, "card tenders must be removed and re-authorized externally before recording a replacement"
    end

    def command_payload
      {
        transaction_id: @transaction.id,
        tender_id: @tender.id,
        expected_lock_version: @expected_lock_version,
        amount_cents: @amount_cents,
        amount_presented_cents: @amount_presented_cents,
        external_reference: @external_reference
      }
    end

    def replace_ordinary!(transaction, original)
      replacement = build_replacement!(transaction, original)
      before = audit_snapshot(original)
      original.destroy!
      replacement.save!
      {
        replacement: replacement,
        before: before,
        applied_cents: replacement.amount_cents,
        capped: false,
        metadata: {}
      }
    end

    # Stored-value replacement keeps the original destination and revalidates the
    # full proposed placement (cap rules, duplicate account excluding the
    # original) before the original is destroyed. Any failure rolls the whole
    # transaction back, so the original is unchanged.
    def replace_stored_value!(transaction, original)
      detail = original.stored_value_tender_detail
      raise Pos::Error, "stored-value tender is missing its detail" if detail.blank?

      type = original.configured_tender_type
      raise Pos::Error, "tender is not available" unless type.active?
      raise Pos::Error, "amount must be positive" unless @amount_cents.positive?

      placement = stored_value_placement(transaction, original, detail, type)
      plan = placement.plan!(transaction, except: original)
      before = audit_snapshot(original)
      tender_number = original.tender_number
      original.destroy!
      transaction.pos_tenders.reload
      replacement = placement.persist_tender!(transaction, plan, tender_number: tender_number)
      applied = replacement.amount_cents
      {
        replacement: replacement,
        before: before,
        applied_cents: applied,
        capped: applied < @amount_cents,
        metadata: {
          requested_cents: @amount_cents,
          applied_cents: applied,
          capped: applied < @amount_cents,
          destination_mode: detail.destination_mode,
          stored_value_account_id: detail.stored_value_account_id,
          masked_card_snapshot: detail.masked_card_snapshot,
          stored_value_ledger_affected: false
        }.compact
      }
    end

    def stored_value_placement(transaction, original, detail, type)
      if original.direction == "refund"
        raise Pos::Error, "tender does not allow refunds" unless type.allows_refund?

        Pos::AddStoredValueRefundTender.new(
          transaction: transaction,
          actor: @actor,
          expected_lock_version: @expected_lock_version,
          tender_type: type,
          amount_cents: @amount_cents,
          destination_mode: detail.destination_mode,
          operation_id: @operation_id,
          existing_detail: detail
        )
      else
        Pos::AddStoredValueTender.new(
          transaction: transaction,
          actor: @actor,
          expected_lock_version: @expected_lock_version,
          tender_type: type,
          amount_cents: @amount_cents,
          operation_id: @operation_id,
          stored_value_account: detail.stored_value_account
        )
      end
    end

    def build_replacement!(transaction, original)
      type = original.configured_tender_type
      raise Pos::Error, "tender is not available" unless type.active?
      raise Pos::Error, "amount must be positive" unless @amount_cents.positive?
      validate_reference!(type)

      available =
        if original.direction == "refund"
          Pos::Support.remaining_refund_cents(transaction, except: original)
        else
          Pos::Support.remaining_payment_cents(transaction, except: original)
        end
      label = original.direction == "refund" ? "refund" : "amount due"
      raise Pos::Error, "no remaining #{label}" unless available.positive?
      raise Pos::Error, "amount is greater than remaining #{label}" if @amount_cents > available
      raise Pos::Error, "tender does not allow refunds" if original.direction == "refund" && !type.allows_refund?

      replacement = transaction.pos_tenders.new(
        direction: original.direction,
        tender_number: original.tender_number,
        amount_cents: @amount_cents,
        external_reference: type.reference_captured? ? @external_reference : nil
      )
      Pos::Support.snapshot_tender_identity!(replacement, type)
      apply_cash_values!(replacement, original, transaction, available) if type.cash?
      replacement
    end

    def apply_cash_values!(replacement, original, transaction, available)
      if original.direction == "refund"
        replacement.amount_presented_cents = nil
        replacement.change_cents = nil
        return
      end

      presented = @amount_presented_cents || @amount_cents
      raise Pos::Error, "presented amount must be positive" unless presented.positive?
      if available == transaction.signed_net_cents && presented < available
        raise Pos::Error, "presented amount is less than amount due"
      end
      applied = [ presented, available ].min
      raise Pos::Error, "applied amount does not match cash presented" unless @amount_cents == applied

      replacement.amount_presented_cents = presented
      replacement.change_cents = presented - applied
      replacement.external_reference = nil
    end

    def validate_reference!(type)
      raise Pos::Error, "reference is required" if type.reference_required? && @external_reference.blank?
    end

    def audit_snapshot(tender)
      tender.slice(
        "id", "tender_number", "tender_type", "tender_name", "behavioral_category",
        "direction", "amount_cents", "amount_presented_cents", "change_cents", "external_reference"
      )
    end

    def replay_result(operation)
      facts = operation.envelope.fetch("facts", {})
      Result.new(
        transaction: operation.pos_transaction,
        tender: PosTender.find_by(id: facts["replacement_tender_id"]),
        operation: operation,
        requested_cents: facts["requested_cents"],
        applied_cents: facts["applied_cents"],
        capped: facts["capped"],
        replayed: true
      )
    end
  end
end
