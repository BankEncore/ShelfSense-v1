# frozen_string_literal: true

module Pos
  # Atomic working issuance replacement: validate the proposed issuance before
  # destroying the original or clearing tenders; mutate everything under one lease.
  class ReplaceStoredValueIssuance
    Result = Data.define(:transaction, :issuance, :operation, :cleared_tender_ids, :replayed)

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      transaction:,
      actor:,
      expected_lock_version:,
      issuance:,
      issuance_type:,
      amount_cents:,
      operation_id:,
      gift_card_program: nil,
      card_number: nil,
      confirm_clear_tenders: false
    )
      @transaction = transaction
      @actor = actor
      @expected_lock_version = expected_lock_version
      @issuance = issuance
      @issuance_type = issuance_type.to_s
      @amount_cents = amount_cents.to_i
      @operation_id = operation_id
      @gift_card_program = gift_card_program
      @card_number = card_number.to_s.strip.presence
      @confirm_clear_tenders = confirm_clear_tenders
    end

    def call
      lease = nil
      Pos::Support.authorize!(@actor, @transaction.store)
      Pos::Support.require_active_context!(@transaction.store, @transaction.register)
      Pos::Support.require_transaction_cashier!(@actor, @transaction)
      raise Pos::Error, "issuance type is invalid" unless PosStoredValueIssuance::ISSUANCE_TYPES.include?(@issuance_type)
      raise Pos::Error, "amount must be positive" unless @amount_cents.positive?

      lease = Pos::OperationLease.begin!(
        register_id: @transaction.register_id,
        operation_id: @operation_id,
        command_payload: command_payload,
        store_id: @transaction.store_id,
        pos_transaction_id: @transaction.id,
        command_type: PosOperation::REPLACE_WORKING_ISSUANCE_COMMAND_TYPE
      )
      return replay_result(lease.operation) if lease.replayed

      result = nil
      PosTransaction.transaction do
        operation = PosOperation.lock.find(lease.operation.id)
        transaction = Pos::Support.lock_working_transaction!(@transaction, @expected_lock_version)
        original = transaction.pos_stored_value_issuances.find(@issuance.id)
        Pos::IssuanceTenderClear.require_confirmation!(transaction, confirmed: @confirm_clear_tenders)

        # Full validation before destroy/clear — failure leaves the original and tenders.
        replacement = build_replacement!(transaction, original)
        replacement.validate!

        before = audit_snapshot(original)
        cleared_ids = Pos::IssuanceTenderClear.clear!(transaction)
        original.destroy!
        replacement.save!
        Pos::Support.refresh_totals!(transaction)
        Pos::Support.touch_working_transaction!(transaction)
        Audit::Recorder.record!(
          action: "pos.working_issuance.replaced",
          outcome: "succeeded",
          actor_user: @actor,
          actor_label: @actor.display_name,
          store: transaction.store,
          register: transaction.register,
          subject: replacement,
          before_values: before,
          after_values: audit_snapshot(replacement),
          metadata: { cleared_tender_ids: cleared_ids.map(&:to_s) }
        )
        Pos::CompleteWorkingOperation.call(
          operation: operation,
          fact_type: PosOperation::REPLACE_WORKING_ISSUANCE_FACT_TYPE,
          facts: {
            replaced_issuance_id: original.id,
            issuance_id: replacement.id,
            issuance_type: replacement.issuance_type,
            amount_cents: replacement.amount_cents,
            gift_card_program_id: replacement.gift_card_program_id,
            masked_card_snapshot: masked_identity(replacement),
            cleared_tender_ids: cleared_ids
          }.compact
        )
        result = Result.new(
          transaction: transaction,
          issuance: replacement,
          operation: operation,
          cleared_tender_ids: cleared_ids,
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

    def command_payload
      {
        transaction_id: @transaction.id,
        issuance_id: @issuance.id,
        expected_lock_version: @expected_lock_version.to_i,
        issuance_type: @issuance_type,
        amount_cents: @amount_cents,
        gift_card_program_id: @gift_card_program&.id,
        card_number_digest: card_number_digest,
        card_last_four: GiftCards::Number.last_four(normalized_card_number)
      }
    end

    def normalized_card_number
      return if @card_number.blank?

      @normalized_card_number ||= GiftCards::Number.normalize(@card_number)
    end

    def card_number_digest
      return if normalized_card_number.blank?

      GiftCards::Number.digest(normalized_card_number)
    end

    def build_replacement!(transaction, original)
      case @issuance_type
      when "activation"
        build_activation!(transaction, original)
      when "reload"
        build_reload!(transaction, original)
      end
    end

    def build_activation!(transaction, original)
      program = @gift_card_program || GiftCards::Lookup.program_for(@card_number) || original.gift_card_program
      raise Pos::Error, "gift-card program is required" if program.blank?
      raise Pos::Error, "gift-card program is not active" unless program.active?
      if program.minimum_activation_cents.present? && @amount_cents < program.minimum_activation_cents
        raise Pos::Error, "activation is below the program minimum"
      end
      if program.maximum_balance_cents.present? && @amount_cents > program.maximum_balance_cents
        raise Pos::Error, "activation exceeds the program maximum"
      end

      issuance = transaction.pos_stored_value_issuances.new(
        issuance_number: original.issuance_number,
        issuance_type: "activation",
        amount_cents: @amount_cents,
        gift_card_program: program,
        number_authority: program.number_authority
      )
      if program.manual_external?
        number = normalized_card_number.presence || original.pending_card_number
        raise Pos::Error, "a card number is required" if number.blank?

        unless GiftCards::Number.shape_match?(number, program: program)
          raise Pos::Error, "card number is not valid for this program"
        end
        digest = GiftCards::Number.digest(number)
        conflict = GiftCards::Lookup.by_number(number) ||
          PosStoredValueIssuance.where(pending_card_number_digest: digest).where.not(id: original.id).exists?
        raise Pos::Error, "card number is already in use" if conflict

        issuance.pending_card_number = number
      elsif @card_number.present?
        raise Pos::Error, "system-generated activations cannot take a card number"
      end
      issuance
    end

    def build_reload!(transaction, original)
      raise Pos::Error, "a card number is required" if @card_number.blank?

      card = GiftCards::Lookup.by_number(@card_number)
      raise Pos::Error, "gift card is not available" unless card
      raise Pos::Error, "gift card is not available" unless card.active?
      raise Pos::Error, "reload is not allowed for this program" unless card.gift_card_program.reload_allowed?
      program = card.gift_card_program
      next_balance = card.stored_value_account.balance_cents + @amount_cents
      if program.maximum_balance_cents.present? && next_balance > program.maximum_balance_cents
        raise Pos::Error, "reload exceeds the program maximum"
      end

      transaction.pos_stored_value_issuances.new(
        issuance_number: original.issuance_number,
        issuance_type: "reload",
        amount_cents: @amount_cents,
        gift_card_program: program,
        gift_card: card,
        number_authority: program.number_authority,
        masked_card_snapshot: card.masked_number
      )
    end

    def audit_snapshot(issuance)
      {
        issuance_id: issuance.id.to_s,
        issuance_number: issuance.issuance_number,
        issuance_type: issuance.issuance_type,
        amount_cents: issuance.amount_cents,
        gift_card_program_id: issuance.gift_card_program_id&.to_s,
        masked_card_snapshot: masked_identity(issuance)
      }.compact
    end

    def masked_identity(issuance)
      return issuance.masked_card_snapshot if issuance.masked_card_snapshot.present?
      return if issuance.pending_card_number_last_four.blank?

      "#{issuance.pending_card_number_prefix}••••#{issuance.pending_card_number_last_four}"
    end

    def replay_result(operation)
      facts = operation.envelope.fetch("facts", {})
      Result.new(
        transaction: operation.pos_transaction,
        issuance: PosStoredValueIssuance.find_by(id: facts["issuance_id"]),
        operation: operation,
        cleared_tender_ids: facts.fetch("cleared_tender_ids", []),
        replayed: true
      )
    end
  end
end
