# frozen_string_literal: true

module Pos
  class CompletedTransactionSearch
    PER_PAGE = 50

    Result = Struct.new(
      :records, :page, :per_page, :total_count, :total_pages,
      :transaction_reference, :register_id, :receipt_sequence, :business_date, :filtered,
      keyword_init: true
    )

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(store:, transaction_reference: nil, register_id: nil, receipt_sequence: nil, business_date: nil, page: 1)
      @store = store
      @transaction_reference = transaction_reference
      @register_id = register_id
      @receipt_sequence = receipt_sequence
      @business_date = business_date
      @page = page
    end

    def call
      relation = PosTransaction.completed.where(store_id: @store.id)
      relation = apply_filters(relation)

      total_count = relation.except(:order, :select).count
      total_pages = [ (total_count.to_f / PER_PAGE).ceil, 1 ].max
      page = parse_page(total_pages)
      offset = (page - 1) * PER_PAGE

      records = relation.includes(:pos_tenders)
                        .order(completed_at: :desc, id: :desc)
                        .offset(offset)
                        .limit(PER_PAGE)

      Result.new(
        records: records,
        page: page,
        per_page: PER_PAGE,
        total_count: total_count,
        total_pages: total_pages,
        transaction_reference: normalized_reference,
        register_id: @register_id.to_s.presence,
        receipt_sequence: @receipt_sequence.to_s.strip.presence,
        business_date: @business_date.to_s.strip.presence,
        filtered: filtered?
      )
    end

    private

    def apply_filters(relation)
      if normalized_reference.present?
        return relation.where(transaction_reference: normalized_reference)
      end

      sequence = parsed_receipt_sequence
      date = parsed_business_date
      return relation.none if sequence == :invalid || date == :invalid

      if @register_id.to_s.present?
        register = @store.registers.find_by(id: @register_id)
        return relation.none unless register

        relation = relation.where(register_id: register.id)
      end
      relation = relation.where(receipt_sequence: sequence) if sequence.present?
      relation = relation.where(business_date: date) if date.present?
      relation
    end

    def normalized_reference
      @transaction_reference.to_s.strip.upcase.presence
    end

    def parsed_receipt_sequence
      return @parsed_receipt_sequence if defined?(@parsed_receipt_sequence)

      raw = @receipt_sequence.to_s.strip
      @parsed_receipt_sequence =
        if raw.blank?
          nil
        elsif raw.match?(/\A\d+\z/)
          value = Integer(raw, 10)
          value.positive? ? value : :invalid
        else
          :invalid
        end
    end

    def parsed_business_date
      return @parsed_business_date if defined?(@parsed_business_date)

      raw = @business_date.to_s.strip
      @parsed_business_date =
        if raw.blank?
          nil
        else
          Date.iso8601(raw)
        end
    rescue Date::Error, ArgumentError
      @parsed_business_date = :invalid
    end

    def filtered?
      normalized_reference.present? ||
        @register_id.to_s.present? ||
        @receipt_sequence.to_s.strip.present? ||
        @business_date.to_s.strip.present?
    end

    def parse_page(total_pages)
      value = Integer(@page)
      return 1 if value < 1

      [ value, total_pages ].min
    rescue ArgumentError, TypeError
      1
    end
  end
end
