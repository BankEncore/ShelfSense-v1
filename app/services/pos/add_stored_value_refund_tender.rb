# frozen_string_literal: true

module Pos
  class AddStoredValueRefundTender
    Result = Data.define(
      :transaction,
      :tender,
      :operation,
      :amount_cents,
      :remaining_refund_cents,
      :replayed
    )

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      transaction:,
      actor:,
      expected_lock_version:,
      tender_type:,
      amount_cents:,
      destination_mode:,
      operation_id:,
      card_number: nil,
      gift_card_program: nil,
      existing_detail: nil
    )
      @transaction = transaction
      @actor = actor
      @expected_lock_version = expected_lock_version
      @tender_type = tender_type
      @amount_cents = amount_cents.to_i
      @destination_mode = destination_mode.to_s
      @operation_id = operation_id
      @card_number = card_number.to_s.strip.presence
      @gift_card_program = gift_card_program
      @existing_detail = existing_detail
    end

    def call
      lease = nil
      Pos::Support.authorize!(@actor, @transaction.store)
      Pos::Support.require_active_context!(@transaction.store, @transaction.register)
      Pos::Support.require_transaction_cashier!(@actor, @transaction)
      validate_request!

      lease = Pos::OperationLease.begin!(
        register_id: @transaction.register_id,
        operation_id: @operation_id,
        command_payload: command_payload,
        store_id: @transaction.store_id,
        pos_transaction_id: @transaction.id,
        command_type: PosOperation::ADD_WORKING_STORED_VALUE_REFUND_TENDER_COMMAND_TYPE
      )
      return replay_result(lease.operation) if lease.replayed

      result = nil
      PosTransaction.transaction do
        operation = PosOperation.lock.find(lease.operation.id)
        transaction = Pos::Support.lock_working_transaction!(@transaction, @expected_lock_version)
        detail_attrs = plan!(transaction)
        tender = persist_tender!(transaction, detail_attrs, tender_number: Pos::Support.next_tender_number(transaction))
        Pos::Support.touch_working_transaction!(transaction)
        record_audit!(transaction, tender, detail_attrs)
        Pos::CompleteWorkingOperation.call(
          operation: operation,
          fact_type: PosOperation::ADD_WORKING_STORED_VALUE_REFUND_TENDER_FACT_TYPE,
          facts: facts_for(tender, detail_attrs)
        )
        result = Result.new(
          transaction: transaction,
          tender: tender,
          operation: operation,
          amount_cents: tender.amount_cents,
          remaining_refund_cents: Pos::Support.remaining_refund_cents(transaction.reload),
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

    # Validates the full proposed refund destination and capacity against the
    # locked transaction, returning the detail attributes to persist.
    def plan!(transaction, except: nil)
      Pos::Support.require_commercial_content!(transaction)
      raise Pos::Error, "transaction does not require a refund" unless Pos::Support.settlement_direction(transaction) == :refund
      remaining = Pos::Support.remaining_refund_cents(transaction, except: except)
      raise Pos::Error, "no remaining refund amount" if remaining <= 0
      raise Pos::Error, "amount is greater than remaining refund" if @amount_cents > remaining

      detail_attrs = build_detail_attrs!(transaction)
      assert_refund_capacity!(transaction, detail_attrs, except: except)
      detail_attrs
    end

    def persist_tender!(transaction, detail_attrs, tender_number:)
      tender = transaction.pos_tenders.new(
        direction: "refund",
        tender_number: tender_number,
        amount_cents: @amount_cents,
        amount_presented_cents: nil,
        change_cents: nil
      )
      Pos::Support.snapshot_tender_identity!(tender, @tender_type)
      tender.save!
      tender.create_stored_value_tender_detail!(detail_attrs)
      tender
    end

    private

    def validate_request!
      raise Pos::Error, "tender is not available" unless @tender_type.active?
      raise Pos::Error, "tender is not stored value" unless @tender_type.stored_value?
      raise Pos::Error, "amount must be positive" unless @amount_cents.positive?
      unless PosStoredValueTenderDetail::DESTINATION_MODES.include?(@destination_mode)
        raise Pos::Error, "refund destination is invalid"
      end
    end

    # Never carries a full card number; only a keyed digest and last four.
    def command_payload
      {
        transaction_id: @transaction.id,
        expected_lock_version: @expected_lock_version.to_i,
        tender_type_id: @tender_type.id,
        tender_type_code: @tender_type.code,
        amount_cents: @amount_cents,
        destination_mode: @destination_mode,
        customer_id: @transaction.customer_id,
        gift_card_program_id: @gift_card_program&.id,
        card_number_digest: card_number_digest,
        card_last_four: card_last_four
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

    def card_last_four
      GiftCards::Number.last_four(normalized_card_number)
    end

    def facts_for(tender, detail_attrs)
      account = detail_attrs[:stored_value_account]
      {
        tender_id: tender.id,
        amount_cents: tender.amount_cents,
        destination_mode: detail_attrs[:destination_mode],
        stored_value_account_id: account&.id,
        gift_card_program_id: detail_attrs[:gift_card_program]&.id,
        masked_card_snapshot: detail_attrs[:masked_card_snapshot]
      }.compact
    end

    def record_audit!(transaction, tender, detail_attrs)
      Audit::Recorder.record!(
        action: "pos.working_stored_value_refund_tender.added",
        outcome: "succeeded",
        actor_user: @actor,
        actor_label: @actor.display_name,
        store: transaction.store,
        register: transaction.register,
        subject: tender,
        after_values: tender.slice(
          "id", "tender_number", "tender_type", "tender_name", "behavioral_category",
          "direction", "amount_cents"
        ),
        metadata: {
          destination_mode: detail_attrs[:destination_mode],
          stored_value_account_id: detail_attrs[:stored_value_account]&.id,
          gift_card_program_id: detail_attrs[:gift_card_program]&.id,
          masked_card_snapshot: detail_attrs[:masked_card_snapshot]
        }.compact
      )
    end

    def build_detail_attrs!(transaction)
      return cloned_detail_attrs! if @existing_detail

      case @destination_mode
      when "existing_account"
        existing_account_attrs!(transaction)
      when "customer_store_credit"
        store_credit_attrs!(transaction)
      when "new_gift_card"
        new_gift_card_attrs!(transaction)
      end
    end

    # Replacement keeps the original destination. The pending card number stays
    # in memory and never enters payloads, facts, or audit metadata.
    def cloned_detail_attrs!
      attrs = {
        destination_mode: @existing_detail.destination_mode,
        stored_value_account: @existing_detail.stored_value_account,
        gift_card: @existing_detail.gift_card,
        gift_card_program: @existing_detail.gift_card_program,
        masked_card_snapshot: @existing_detail.masked_card_snapshot
      }.compact
      attrs[:pending_card_number] = @existing_detail.pending_card_number if @existing_detail.pending_card_number.present?
      if attrs[:destination_mode] == "new_gift_card"
        program = attrs[:gift_card_program]
        raise Pos::Error, "gift-card program is not active" unless program&.active?
        if program.maximum_balance_cents.present? && @amount_cents > program.maximum_balance_cents
          raise Pos::Error, "credit would exceed the program maximum balance"
        end
      end
      if attrs[:destination_mode] == "existing_account" && attrs[:gift_card].present?
        assert_gift_card_credit_within_maximum!(attrs[:gift_card])
      end
      attrs
    end

    def existing_account_attrs!(transaction)
      case @tender_type.stored_value_account_type
      when "gift_card"
        raise Pos::Error, "original gift-card refund requires a presented card" if @card_number.blank?
        raise Pos::Error, "gift card cannot receive this refund" unless original_gift_card_funded?(transaction)

        card = GiftCards::Lookup.by_number(@card_number)
        raise Pos::Error, "gift card is not available" unless card&.active?
        unless original_gift_card_accounts(transaction).include?(card.stored_value_account_id)
          raise Pos::Error, "presented gift card does not match the original tender"
        end
        assert_gift_card_credit_within_maximum!(card)
        { destination_mode: "existing_account", stored_value_account: card.stored_value_account, gift_card: card, masked_card_snapshot: card.masked_number }
      when "trade_credit"
        raise Pos::Error, "trade credit is not a generic refund destination" unless @tender_type.allows_original_tender_refund?
        account_ids = original_trade_credit_accounts(transaction)
        raise Pos::Error, "trade credit can only return to the original account" if account_ids.empty?
        raise Pos::Error, "a customer is required" if transaction.customer.blank?

        account = StoredValueAccount.where(id: account_ids, customer_id: transaction.customer_id, account_type: "trade_credit")
                                    .where.not(status: "closed").order(:id).first
        raise Pos::Error, "original trade-credit account is not available" unless account&.active?

        { destination_mode: "existing_account", stored_value_account: account }
      when "store_credit"
        raise Pos::Error, "a customer is required" if transaction.customer.blank?
        raise Pos::Error, "customer must be an active canonical customer" unless transaction.customer.canonical? && transaction.customer.active?

        account = StoredValueAccount.where(customer_id: transaction.customer_id, account_type: "store_credit")
                                    .where.not(status: "closed").order(:id).first
        { destination_mode: "existing_account", stored_value_account: account }.compact
      else
        raise Pos::Error, "refund destination is invalid"
      end
    end

    def store_credit_attrs!(transaction)
      raise Pos::Error, "store credit cannot receive this refund" unless @tender_type.code == "store_credit"
      raise Pos::Error, "a customer is required" if transaction.customer.blank?
      raise Pos::Error, "customer must be an active canonical customer" unless transaction.customer.canonical? && transaction.customer.active?

      { destination_mode: "customer_store_credit" }
    end

    def new_gift_card_attrs!(transaction)
      raise Pos::Error, "new refund gift cards require the gift-card tender" unless @tender_type.code == "gift_card"
      raise Pos::Error, "new refund gift card is not allowed" unless @tender_type.allows_refund_instrument_replacement?
      raise Pos::Error, "new gift card cannot receive this refund" unless original_gift_card_funded?(transaction)

      program = @gift_card_program || GiftCards::Lookup.program_for(@card_number)
      raise Pos::Error, "gift-card program is required" if program.blank?
      raise Pos::Error, "gift-card program is not active" unless program.active?
      if program.maximum_balance_cents.present? && @amount_cents > program.maximum_balance_cents
        raise Pos::Error, "credit would exceed the program maximum balance"
      end

      attrs = { destination_mode: "new_gift_card", gift_card_program: program }
      if program.manual_external?
        raise Pos::Error, "a card number is required" if @card_number.blank?

        number = GiftCards::Number.normalize(@card_number)
        unless GiftCards::Number.shape_match?(number, program: program)
          raise Pos::Error, "card number is not valid for this program"
        end
        if GiftCards::Lookup.by_number(number)
          raise Pos::Error, "card number is already in use"
        end
        attrs[:pending_card_number] = number
      elsif @card_number.present?
        raise Pos::Error, "system-generated refund cards cannot take a card number"
      end
      attrs
    end

    def assert_refund_capacity!(transaction, detail_attrs, except: nil)
      remaining = Pos::StoredValueRefundCapacity.remaining_cents(
        transaction: transaction,
        tender_type: @tender_type,
        destination_mode: detail_attrs[:destination_mode],
        account_id: detail_attrs[:stored_value_account]&.id || detail_attrs[:stored_value_account_id],
        except: except
      )
      return if remaining.nil?

      kind = @tender_type.stored_value_account_type == "trade_credit" ? "trade-credit-funded" : "gift-card-funded"
      if remaining <= 0
        raise Pos::Error, "#{detail_attrs[:destination_mode] == 'new_gift_card' ? 'new gift card' : @tender_type.name.downcase} cannot receive this refund"
      end
      raise Pos::Error, "refund exceeds remaining #{kind} amount" if @amount_cents > remaining
    end

    def assert_gift_card_credit_within_maximum!(card)
      GiftCards::MaximumBalance.assert!(
        account: card.stored_value_account,
        next_balance_cents: card.stored_value_account.balance_cents + @amount_cents
      )
    rescue StoredValue::Error => e
      raise Pos::Error, e.message
    end

    def original_gift_card_funded?(transaction)
      original_gift_card_accounts(transaction).any?
    end

    def original_gift_card_accounts(transaction)
      original_payment_accounts(transaction, "gift_card")
    end

    def original_trade_credit_accounts(transaction)
      original_payment_accounts(transaction, "trade_credit")
    end

    def original_payment_accounts(transaction, tender_code)
      original_ids = transaction.pos_transaction_lines.filter_map(&:original_transaction_line_id)
      return [] if original_ids.empty?

      original_transaction_ids = PosTransactionLine.where(id: original_ids).distinct.pluck(:pos_transaction_id)
      PosTender.where(pos_transaction_id: original_transaction_ids, tender_type: tender_code, direction: "payment")
               .includes(:stored_value_tender_detail)
               .filter_map { |tender| tender.stored_value_tender_detail&.stored_value_account_id }
               .uniq
    end

    def replay_result(operation)
      facts = operation.envelope.fetch("facts", {})
      transaction = operation.pos_transaction
      Result.new(
        transaction: transaction,
        tender: PosTender.find_by(id: facts["tender_id"]),
        operation: operation,
        amount_cents: facts["amount_cents"],
        remaining_refund_cents: transaction && Pos::Support.remaining_refund_cents(transaction),
        replayed: true
      )
    end
  end
end
