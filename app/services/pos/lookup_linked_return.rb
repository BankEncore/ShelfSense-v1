# frozen_string_literal: true

module Pos
  class LookupLinkedReturn
    LIMIT = 20
    LINE_BATCH = 50

    Result = Struct.new(:outcome, :receipts, :lines, :truncated, :message, :transaction_id, keyword_init: true)
    Receipt = Struct.new(:id, :transaction_reference, :completed_at, keyword_init: true)
    Line = Struct.new(
      :id, :description, :remaining, :sold, :quantity_fixed, :unit_identifier,
      keyword_init: true
    )

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(store:, query: nil, transaction_id: nil, current_transaction: nil)
      @store = store
      @query = query.to_s.strip
      @transaction_id = transaction_id
      @current_transaction = current_transaction
    end

    def call
      if @transaction_id.present?
        return lines_for_transaction(find_store_transaction(@transaction_id))
      end
      return empty("enter a receipt, merchandise, or unit identifier") if @query.blank?

      by_reference = find_by_transaction_reference
      return lines_for_transaction(by_reference) if by_reference

      resolve_identifier
    end

    private

    def find_by_transaction_reference
      reference = @query.upcase
      PosTransaction.completed.find_by(store_id: @store.id, transaction_reference: reference)
    end

    def find_store_transaction(id)
      PosTransaction.completed.find_by(id: id, store_id: @store.id)
    end

    def resolve_identifier
      result = Identifiers::Lookup.call(@query)
      case result.status
      when :inventory_unit
        transactions_for_unit(result.inventory_unit)
      when :variant
        transactions_for_variant(result.variant)
      when :product
        # Return eligibility is decided by completed sale lines, not POS sellability.
        transactions_for_variants(result.product.product_variants.to_a)
      when :multiple_products
        empty("multiple products share that lookup code. Scan a variant or unit identifier.")
      when :retired
        empty("identifier is retired")
      else
        empty("no returnable original found")
      end
    end

    def transactions_for_unit(unit)
      line = completed_sale_lines.where(inventory_unit_id: unit.id).order("pos_transactions.completed_at DESC").first
      return empty("no returnable original found") unless line

      lines_for_transaction(line.pos_transaction)
    end

    def transactions_for_variant(variant)
      transactions_for_variants([ variant ])
    end

    def transactions_for_variants(variants)
      eligible_transactions = collect_eligible_transactions(variants.map(&:id))
      return empty("no returnable original found") if eligible_transactions.empty?
      return lines_for_transaction(eligible_transactions.first) if eligible_transactions.one?

      receipts_result(eligible_transactions)
    end

    def collect_eligible_transactions(variant_ids)
      eligible = []
      seen = Set.new
      offset = 0
      needed = LIMIT + 1

      loop do
        batch = completed_sale_lines
                .where(product_variant_id: variant_ids)
                .preload(:pos_transaction)
                .order(
                  "pos_transactions.completed_at DESC",
                  "pos_transactions.transaction_reference ASC",
                  "pos_transaction_lines.line_number ASC"
                )
                .offset(offset)
                .limit(LINE_BATCH)
                .to_a
        break if batch.empty?

        unique_returnable_transactions(batch).each do |transaction|
          next if seen.include?(transaction.id)

          seen.add(transaction.id)
          eligible << transaction
          return eligible if eligible.size >= needed
        end

        break if batch.size < LINE_BATCH

        offset += LINE_BATCH
      end

      eligible
    end

    def unique_returnable_transactions(lines)
      summaries = Pos::Returnability.summary_for(lines)
      basket = basket_original_ids
      lines.filter_map do |line|
        next unless summaries[line.id]&.remaining_quantity.to_i.positive?
        next if basket.include?(line.id)

        line.pos_transaction
      end.uniq
    end

    def receipts_result(transactions)
      truncated = transactions.size > LIMIT
      selected = transactions.first(LIMIT)
      Result.new(
        outcome: :receipts,
        receipts: selected.map { |transaction| serialize_receipt(transaction) },
        truncated: truncated,
        message: truncated ? "More than #{LIMIT} originals. Scan a receipt or use Transactions." : nil
      )
    end

    def lines_for_transaction(transaction)
      return empty("no returnable original found") if transaction.nil?
      return empty("original sale has been post-voided") if Pos::Returnability.post_voided_source?(transaction.id)

      sale_lines = transaction.pos_transaction_lines.select { |line| line.sale? && !line.post_void_generated? }
      summaries = Pos::Returnability.summary_for(sale_lines)
      basket = basket_original_ids
      eligible = sale_lines.filter_map do |line|
        remaining = summaries[line.id]&.remaining_quantity.to_i
        next if remaining <= 0 || basket.include?(line.id)

        serialize_line(line, remaining)
      end
      if eligible.empty?
        return empty("no returnable lines on this receipt")
      end

      Result.new(
        outcome: :lines,
        transaction_id: transaction.id,
        lines: eligible,
        truncated: false
      )
    end

    def completed_sale_lines
      PosTransactionLine.joins(:pos_transaction)
                        .where(pos_transactions: { store_id: @store.id, status: "completed" })
                        .where(direction: "sale")
                        .where(post_void_source_line_id: nil)
    end

    def basket_original_ids
      return Set.new unless @current_transaction

      @basket_original_ids ||= @current_transaction.pos_transaction_lines
                                                   .select(&:linked_return?)
                                                   .map(&:original_transaction_line_id)
                                                   .to_set
    end

    def serialize_receipt(transaction)
      Receipt.new(
        id: transaction.id,
        transaction_reference: transaction.transaction_reference,
        completed_at: transaction.completed_at
      )
    end

    def serialize_line(line, remaining)
      snapshot = line.merchandise_snapshot.is_a?(Hash) ? line.merchandise_snapshot : {}
      Line.new(
        id: line.id,
        description: snapshot["description"].presence || line.product_variant&.product&.name,
        remaining: remaining,
        sold: line.quantity,
        quantity_fixed: line.unit_line?,
        unit_identifier: snapshot["unit_identifier"]
      )
    end

    def empty(message)
      Result.new(outcome: :empty, message: message, truncated: false)
    end
  end
end
