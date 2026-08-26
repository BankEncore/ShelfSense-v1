# frozen_string_literal: true

module Pos
  class CustomerReceipt
    MISSING_LEGAL_NAME = "This Store cannot print a customer receipt until its legal name is configured."
    LETTERS = ("A".."Z").to_a.freeze

    Line = Struct.new(
      :kind_banner, :identifier, :condition, :description, :amount_cents, :tax_indicators,
      :quantity, :unit_price_cents, :show_unit_price, :extended_price_cents, :discount_cents,
      :discount_label, :original_reference, :unlinked, keyword_init: true
    )
    TaxGroup = Struct.new(:letter, :name, :rate_percent, :basis_cents, :tax_cents, keyword_init: true)
    TenderLine = Struct.new(:label, :amount_cents, :presented_cents, :change_cents, keyword_init: true)
    RemainingBalanceNote = Struct.new(:label, :masked_card, :balance_cents, keyword_init: true)

    def self.build(transaction)
      new(transaction).tap(&:prepare!)
    end

    attr_reader :transaction, :error, :lines, :tax_groups, :tenders, :remaining_balance_notes

    def initialize(transaction)
      @transaction = transaction
      @store = transaction.store
      @error = nil
      @lines = []
      @tax_groups = []
      @tenders = []
      @remaining_balance_notes = []
      @indicator_by_key = {}
    end

    def prepare!
      if @store.legal_name.blank?
        @error = MISSING_LEGAL_NAME
        return self
      end

      assign_tax_groups!
      @lines = customer_lines
      @tenders = customer_tenders
      @remaining_balance_notes = remaining_balance_notes_for_print
      verify_total!
      self
    end

    def printable?
      error.blank?
    end

    def reprint?
      false
    end

    def legal_name
      @store.legal_name
    end

    def address_lines
      lines = []
      lines << @store.street_address_1.presence
      lines << @store.street_address_2.presence
      locality = [ @store.city.presence, @store.region_code.presence ].compact.join(", ")
      locality = [ locality.presence, @store.postal_code.presence ].compact.join(" ")
      lines << locality.presence
      lines << @store.phone.presence
      lines.compact
    end

    def header_message
      Pos::ReceiptMessages.header(@store)
    end

    def footer_message
      Pos::ReceiptMessages.footer(@store)
    end

    def completed_at_label
      zone = ActiveSupport::TimeZone[@store.timezone] || ActiveSupport::TimeZone["UTC"]
      @transaction.completed_at.in_time_zone(zone).strftime("%-d %b %y %-l:%M%P")
    end

    def identity_header
      Pos::ReceiptIdentity.header(
        store_number: @transaction.store_number_snapshot,
        register_number: @transaction.register_number_snapshot,
        receipt_sequence: @transaction.receipt_sequence
      )
    end

    def compact_reference
      @transaction.transaction_reference
    end

    def barcode_svg
      Pos::Code128.svg(compact_reference)
    end

    def cashier_name
      @transaction.cashier_name_snapshot.presence || "Not captured"
    end

    def merchandise_cents
      @transaction.subtotal_cents
    end

    def discounts_cents
      -@transaction.discount_cents
    end

    def returns_cents
      -(@transaction.return_subtotal_cents - @transaction.return_discount_cents)
    end

    def subtotal_cents
      merchandise_cents + discounts_cents + returns_cents
    end

    def total_tax_cents
      @transaction.tax_cents - @transaction.return_tax_cents
    end

    def signed_net_cents
      @transaction.signed_net_cents
    end

    def show_detail_totals?
      @transaction.discount_cents.positive? || @transaction.return_total_cents.positive? ||
        @transaction.stored_value_issuance_cents.to_i != 0 ||
        @transaction.pos_transaction_lines.any?(&:return?)
    end

    def refund_total?
      signed_net_cents.negative?
    end

    def total_label
      refund_total? ? "REFUND TOTAL" : "TOTAL"
    end

    def total_display_cents
      signed_net_cents.abs
    end

    def show_tenders?
      signed_net_cents != 0
    end

    def items_sold
      ordinary_lines.select(&:sale?).sum(&:quantity)
    end

    def items_returned
      ordinary_lines.select(&:return?).sum(&:quantity)
    end

    def you_saved_cents
      return 0 if @transaction.post_void?

      @transaction.discount_cents
    end

    def post_void_reversal?
      @transaction.post_void?
    end

    def post_voided_original?
      @transaction.post_void.present?
    end

    def original_reference
      @transaction.post_void_of&.transaction_reference
    end

    def reversing_reference
      @transaction.post_void&.transaction_reference
    end

    private

    def ordinary_lines
      @transaction.pos_transaction_lines.reject(&:post_void_generated?)
    end

    def assign_tax_groups!
      groups = Hash.new { |hash, key| hash[key] = [] }
      @transaction.pos_transaction_lines.each do |line|
        line.pos_line_tax_components.select(&:applies).each do |component|
          groups[[ component.store_tax_id, component.rate_percent ]] << [ line, component ]
        end
      end

      ordered = groups.sort_by do |(_key, members)|
        [
          members.map { |(_line, component)| component.calculation_order }.min,
          members.first.last.store_tax_code_snapshot.to_s,
          members.first.last.rate_percent
        ]
      end

      @tax_groups = ordered.each_with_index.map do |(key, members), index|
        letter = LETTERS.fetch(index)
        @indicator_by_key[key] = letter
        sample = members.first.last
        basis = members.sum { |line, component| signed_amount(line, component.taxable_basis_cents) }
        tax = members.sum { |line, component| signed_amount(line, component.tax_cents) }
        TaxGroup.new(
          letter: letter,
          name: sample.store_tax_name_snapshot,
          rate_percent: sample.rate_percent,
          basis_cents: basis,
          tax_cents: tax
        )
      end
    end

    def signed_amount(line, cents)
      line.return? ? -cents : cents
    end

    def customer_lines
      @transaction.pos_transaction_lines.map { |line| build_line(line) } + issuance_lines
    end

    def issuance_lines
      @transaction.pos_stored_value_issuances.ordered.map do |issuance|
        label = issuance.activation? ? "Gift card activation" : "Gift card reload"
        masked = issuance.masked_card_snapshot
        Line.new(
          kind_banner: nil,
          identifier: masked.to_s,
          condition: nil,
          description: [ label, issuance.gift_card_program&.name, masked ].compact.join(" · "),
          amount_cents: issuance.post_void_generated? ? -issuance.amount_cents : issuance.amount_cents,
          tax_indicators: "",
          quantity: 1,
          unit_price_cents: issuance.amount_cents,
          show_unit_price: false,
          extended_price_cents: issuance.amount_cents,
          discount_cents: 0,
          discount_label: nil,
          original_reference: nil,
          unlinked: false
        )
      end
    end

    def build_line(line)
      snapshot = line.merchandise_snapshot.is_a?(Hash) ? line.merchandise_snapshot : {}
      identifier = snapshot["unit_identifier"].presence || snapshot["sku"].presence || ""
      Line.new(
        kind_banner: line_banner(line),
        identifier: identifier,
        condition: used_condition(snapshot),
        description: snapshot["description"].presence || "Description unavailable",
        amount_cents: signed_amount(line, line.net_merchandise_amount_cents),
        tax_indicators: tax_indicators_for(line),
        quantity: line.quantity,
        unit_price_cents: line.selling_unit_price_cents,
        show_unit_price: line.quantity > 1 || line.manual_discount_cents.to_i.positive?,
        extended_price_cents: line.extended_selling_amount_cents,
        discount_cents: line.manual_discount_cents.to_i.positive? ? -line.manual_discount_cents : 0,
        discount_label: discount_label(line),
        original_reference: original_reference_for(line),
        unlinked: line.unlinked_return?
      )
    end

    def line_banner(line)
      return if line.post_void_generated?
      return "UNLINKED RETURN" if line.unlinked_return?
      return "RETURN" if line.return?

      nil
    end

    def used_condition(snapshot)
      return if snapshot["unit_identifier"].blank?

      name = snapshot["condition_name"].presence || snapshot["condition_code"].presence
      name.present? ? "Used #{name}" : nil
    end

    def tax_indicators_for(line)
      line.pos_line_tax_components.select(&:applies).filter_map { |component|
        @indicator_by_key[[ component.store_tax_id, component.rate_percent ]]
      }.uniq.join
    end

    def discount_label(line)
      return if line.manual_discount_cents.to_i <= 0
      return "Discount:" if line.manual_discount_basis_points.blank?

      percent = line.manual_discount_basis_points / 100.0
      formatted = (percent % 1).zero? ? percent.to_i.to_s : ActiveSupport::NumberHelper.number_to_rounded(percent, precision: 2)
      "Discount #{formatted}%:"
    end

    def original_reference_for(line)
      return unless line.linked_return?

      original = line.original_transaction_line&.pos_transaction
      return if original.blank?

      original.transaction_reference
    end

    def customer_tenders
      return [] unless show_tenders?

      @transaction.pos_tenders.sort_by(&:tender_number).map do |tender|
        label = tender.direction == "refund" ? "#{tender.tender_name} Refund" : tender.tender_name
        presented = pos_cash_payment?(tender) ? tender.amount_presented_cents : nil
        change = pos_cash_payment?(tender) ? tender.change_cents : nil
        TenderLine.new(label: label, amount_cents: tender.amount_cents, presented_cents: presented, change_cents: change)
      end
    end

    def pos_cash_payment?(tender)
      tender.cash? && tender.direction == "payment"
    end

    def remaining_balance_notes_for_print
      notes = []
      @transaction.pos_stored_value_issuances.ordered.each do |issuance|
        card = issuance.gift_card
        next unless card

        notes << RemainingBalanceNote.new(
          label: "Remaining balance",
          masked_card: issuance.masked_card_snapshot.presence || card.masked_number,
          balance_cents: card.balance_cents
        )
      end
      @transaction.pos_tenders.ordered.each do |tender|
        detail = tender.stored_value_tender_detail
        card = detail&.gift_card
        next unless card

        notes << RemainingBalanceNote.new(
          label: "Remaining balance",
          masked_card: detail.masked_card_snapshot.presence || card.masked_number,
          balance_cents: card.balance_cents
        )
      end
      notes
    end

    def verify_total!
      tax_sum = @tax_groups.sum(&:tax_cents)
      unless tax_sum == total_tax_cents
        raise Pos::Error, "receipt tax components do not equal persisted tax"
      end

      computed = subtotal_cents + total_tax_cents + @transaction.stored_value_issuance_cents.to_i
      return if computed == signed_net_cents

      raise Pos::Error, "receipt total does not equal signed_net_cents"
    end
  end
end
