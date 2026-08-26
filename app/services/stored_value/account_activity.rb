# frozen_string_literal: true

module StoredValue
  class AccountActivity
    PER_PAGE = 25
    ANOTHER_STORE_LABEL = "Another store"

    Result = Struct.new(
      :account, :entries, :rows, :page, :per_page, :total_count, :total_pages, :pos_transactions_by_operation_id,
      keyword_init: true
    )
    Row = Struct.new(
      :business_date, :store_label, :operation_label, :amount_cents, :balance_after_cents,
      :actor_reason, :pos_transaction, :redacted, keyword_init: true
    )

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(account:, actor:, permission_key:, page: 1)
      @account = account
      @actor = actor
      @permission_key = permission_key
      @requested_page = page
    end

    def call
      scope = @account.stored_value_entries
                      .joins(:stored_value_operation)
                      .preload(stored_value_operation: [ :store, :performed_by, :reversal_of, :reversed_by ])
                      .order(
                        StoredValueOperation.arel_table[:occurred_at].desc,
                        StoredValueOperation.arel_table[:id].desc,
                        StoredValueEntry.arel_table[:entry_sequence].desc
                      )
      total_count = @account.stored_value_entries.count
      total_pages = [ (total_count.to_f / PER_PAGE).ceil, 1 ].max
      page = parse_page(total_pages)
      entries = scope.offset((page - 1) * PER_PAGE).limit(PER_PAGE).to_a
      pos_transactions = pos_transactions_for(entries)

      Result.new(
        account: @account,
        entries: entries,
        rows: entries.map { |entry| build_row(entry, pos_transactions) },
        page: page,
        per_page: PER_PAGE,
        total_count: total_count,
        total_pages: total_pages,
        pos_transactions_by_operation_id: pos_transactions
      )
    end

    private

    def parse_page(total_pages)
      value = Integer(@requested_page)
      value = 1 if value < 1
      [ value, total_pages ].min
    rescue ArgumentError, TypeError
      1
    end

    def pos_transactions_for(entries)
      op_ids = entries.map(&:stored_value_operation_id)
      return {} if op_ids.empty?

      map = {}
      PosStoredValueIssuance.where(stored_value_operation_id: op_ids).includes(:pos_transaction).find_each do |issuance|
        map[issuance.stored_value_operation_id] = issuance.pos_transaction
      end
      PosStoredValueTenderDetail.where(stored_value_operation_id: op_ids)
                                .includes(pos_tender: :pos_transaction)
                                .find_each do |detail|
        map[detail.stored_value_operation_id] ||= detail.pos_tender.pos_transaction
      end
      map
    end

    def build_row(entry, pos_transactions)
      operation = entry.stored_value_operation
      authorized = store_authorized?(operation.store)
      actor_reason = [
        operation.reason_name_snapshot.presence || operation.reason_code.presence,
        operation.performed_by&.display_name
      ].compact.join(" · ")

      Row.new(
        business_date: operation.business_date,
        store_label: authorized ? operation.store.admin_label : ANOTHER_STORE_LABEL,
        operation_label: operation_label(entry),
        amount_cents: entry.amount_cents,
        balance_after_cents: entry.balance_after_cents,
        actor_reason: authorized ? actor_reason.presence : nil,
        pos_transaction: authorized ? pos_transactions[operation.id] : nil,
        redacted: !authorized
      )
    end

    def store_authorized?(store)
      Authorization::PermissionEvaluator.allowed?(
        user: @actor,
        permission_key: @permission_key,
        store: store
      )
    end

    def operation_label(entry)
      operation = entry.stored_value_operation
      label = base_operation_label(entry)
      return label if operation.reverse?
      return "#{label} (reversed)" if operation.reversed?

      label
    end

    def base_operation_label(entry)
      operation = entry.stored_value_operation
      case operation.operation_type
      when "transfer"
        entry.amount_cents.positive? ? "Transfer in" : "Transfer out"
      when "adjust"
        entry.amount_cents.positive? ? "Credit adjustment" : "Debit adjustment"
      when "reverse"
        reversal_label(operation)
      when "activate"
        "Activate"
      when "reload"
        "Reload"
      when "redeem"
        "Redeem"
      when "refund"
        "Refund"
      when "cash_out"
        "Cash-out"
      when "issue"
        "Issue"
      else
        operation.operation_type.humanize
      end
    end

    def reversal_label(operation)
      original_type = operation.reversal_of&.operation_type
      case original_type
      when "cash_out"
        "Cash-out reversal"
      when "activate", "reload", "redeem", "refund"
        "Post-void reversal"
      when "adjust"
        "Adjustment reversal"
      when "transfer"
        "Transfer reversal"
      when nil
        "Reversal"
      else
        "Reversal of #{original_type.tr('_', ' ')}"
      end
    end
  end
end
