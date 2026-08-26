# frozen_string_literal: true

module Pos
  class StoredValueRefundCapacity
    def self.remaining_cents(transaction:, tender_type:, destination_mode:, account_id: nil)
      new(transaction).remaining_cents(
        tender_type: tender_type,
        destination_mode: destination_mode,
        account_id: account_id
      )
    end

    def self.assert_working_allocation!(transaction)
      new(transaction, include_working: false).assert_allocation!(refund_stored_value_tenders(transaction))
    end

    def self.refund_stored_value_tenders(transaction)
      transaction.pos_tenders.ordered.select { |tender| tender.stored_value? && tender.direction == "refund" }
    end

    def initialize(transaction, include_working: true)
      @transaction = transaction
      @include_working = include_working
    end

    def remaining_cents(tender_type:, destination_mode:, account_id: nil)
      code = tender_type.respond_to?(:code) ? tender_type.code : tender_type.to_s
      case code
      when "gift_card"
        pool = gift_card_pool
        allowed_from_pool(pool, destination_mode: destination_mode, account_id: account_id)
      when "trade_credit"
        pool = trade_credit_pool
        allowed_from_pool(pool, destination_mode: "existing_account", account_id: account_id)
      else
        nil
      end
    end

    def assert_allocation!(tenders)
      gift = gift_card_pool
      trade = trade_credit_pool
      tenders.each do |tender|
        detail = tender.stored_value_tender_detail
        next if detail.blank?

        case tender.tender_type
        when "gift_card"
          allowed = allowed_from_pool(gift, destination_mode: detail.destination_mode, account_id: detail.stored_value_account_id)
          if tender.amount_cents > allowed
            raise Pos::Error, "refund exceeds remaining gift-card-funded amount"
          end

          gift[:total] -= tender.amount_cents
          consume_account!(gift, detail.stored_value_account_id, tender.amount_cents) if detail.existing_account?
        when "trade_credit"
          allowed = allowed_from_pool(trade, destination_mode: "existing_account", account_id: detail.stored_value_account_id)
          if tender.amount_cents > allowed
            raise Pos::Error, "refund exceeds remaining trade-credit-funded amount"
          end

          trade[:total] -= tender.amount_cents
          consume_account!(trade, detail.stored_value_account_id, tender.amount_cents)
        end
      end
    end

    private

    def allowed_from_pool(pool, destination_mode:, account_id:)
      if destination_mode == "new_gift_card"
        pool[:total]
      else
        [ pool[:by_account].fetch(account_id, 0), pool[:total] ].min
      end
    end

    def consume_account!(pool, account_id, amount_cents)
      return if account_id.blank?

      pool[:by_account][account_id] = pool[:by_account].fetch(account_id, 0) - amount_cents
    end

    def gift_card_pool
      pool_for("gift_card")
    end

    def trade_credit_pool
      pool_for("trade_credit")
    end

    def pool_for(tender_code)
      funded_by_account = Hash.new(0)
      payment_tenders(tender_code).each do |tender|
        account_id = tender.stored_value_tender_detail&.stored_value_account_id
        next if account_id.blank?

        funded_by_account[account_id] += tender.amount_cents
      end

      consumed_by_account = Hash.new(0)
      consumed_total = 0
      refund_tenders(tender_code).each do |tender|
        detail = tender.stored_value_tender_detail
        next if detail.blank?

        consumed_total += tender.amount_cents
        consumed_by_account[detail.stored_value_account_id] += tender.amount_cents if detail.existing_account?
      end

      remaining_by_account = {}
      funded_by_account.each do |account_id, funded|
        remaining_by_account[account_id] = [ funded - consumed_by_account[account_id], 0 ].max
      end

      {
        total: [ funded_by_account.values.sum - consumed_total, 0 ].max,
        by_account: remaining_by_account
      }
    end

    def payment_tenders(tender_code)
      ids = active_original_transaction_ids
      return PosTender.none if ids.empty?

      PosTender.where(pos_transaction_id: ids, tender_type: tender_code, direction: "payment")
               .includes(:stored_value_tender_detail)
    end

    def refund_tenders(tender_code)
      tenders = PosTender.where(pos_transaction_id: completed_refund_transaction_ids, tender_type: tender_code, direction: "refund")
                         .includes(:stored_value_tender_detail)
                         .to_a
      tenders.concat(working_refund_tenders(tender_code)) if @include_working
      tenders
    end

    def working_refund_tenders(tender_code)
      self.class.refund_stored_value_tenders(@transaction).select { |tender| tender.tender_type == tender_code }
    end

    def active_original_transaction_ids
      commercially_active(original_transaction_ids)
    end

    def original_transaction_ids
      original_line_ids = @transaction.pos_transaction_lines.filter_map(&:original_transaction_line_id)
      return [] if original_line_ids.empty?

      PosTransactionLine.where(id: original_line_ids).distinct.pluck(:pos_transaction_id)
    end

    def completed_refund_transaction_ids
      original_ids = active_original_transaction_ids
      return [] if original_ids.empty?

      original_line_ids = PosTransactionLine.where(pos_transaction_id: original_ids).pluck(:id)
      refund_ids = PosTransactionLine.where(original_transaction_line_id: original_line_ids)
                                     .where.not(pos_transaction_id: @transaction.id)
                                     .distinct
                                     .pluck(:pos_transaction_id)
      commercially_active(
        PosTransaction.completed.where(id: refund_ids, post_void_of_transaction_id: nil).pluck(:id)
      )
    end

    def commercially_active(ids)
      ids = Array(ids).uniq
      return [] if ids.empty?

      voided = PosTransaction.completed.where(post_void_of_transaction_id: ids).pluck(:post_void_of_transaction_id)
      ids - voided
    end
  end
end
