# frozen_string_literal: true

module StoredValue
  class AccountActivity
    PER_PAGE = 25

    Result = Struct.new(
      :account, :entries, :page, :per_page, :total_count, :total_pages, :pos_transactions_by_operation_id,
      keyword_init: true
    )

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(account:, page: 1)
      @account = account
      @requested_page = page
    end

    def call
      scope = @account.stored_value_entries
                      .includes(stored_value_operation: [ :store, :performed_by ])
                      .order(created_at: :desc, entry_sequence: :desc)
      total_count = scope.count
      total_pages = [ (total_count.to_f / PER_PAGE).ceil, 1 ].max
      page = parse_page(total_pages)
      entries = scope.offset((page - 1) * PER_PAGE).limit(PER_PAGE).to_a

      Result.new(
        account: @account,
        entries: entries,
        page: page,
        per_page: PER_PAGE,
        total_count: total_count,
        total_pages: total_pages,
        pos_transactions_by_operation_id: pos_transactions_for(entries)
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
  end
end
