# frozen_string_literal: true

module Pos
  class CustomerReceipt
    MISSING_LEGAL_NAME = "This Store cannot print a customer receipt until its legal name is configured."
    LETTERS = ("A".."Z").to_a.freeze

    MerchandiseLine = Struct.new(
      :kind_banner, :description, :amount_cents, :tax_indicators,
      :identifier_label, :identifier_value, :condition,
      :quantity, :unit_price_cents, :show_quantity_detail,
      :regular_price_cents, :discount_cents, :discount_label,
      :original_reference, :unlinked, keyword_init: true
    )
    StoredValueIssuanceLine = Struct.new(
      :title, :masked_card, :amount_cents, :activation, keyword_init: true
    )
    TaxGroup = Struct.new(:letter, :name, :rate_percent, :basis_cents, :tax_cents, keyword_init: true)
    PaymentLine = Struct.new(
      :label, :amount_cents, :cash_tendered_cents, :cash_applied_cents, :change_cents,
      :inline_balance_note, keyword_init: true
    )
    BalanceNote = Struct.new(:label, :masked_card, :balance_cents, keyword_init: true)

    def self.build(transaction)
      new(transaction).tap(&:prepare!)
    end

    attr_reader :transaction, :error, :merchandise_lines, :stored_value_issuances,
                :tax_groups, :payments, :tender_balance_notes, :issued_balance_notes

    def initialize(transaction)
      @transaction = transaction
      @store = transaction.store
      @error = nil
      @merchandise_lines = []
      @stored_value_issuances = []
      @tax_groups = []
      @payments = []
      @tender_balance_notes = []
      @issued_balance_notes = []
      @indicator_by_key = {}
    end

    def prepare!
      if @store.legal_name.blank?
        @error = MISSING_LEGAL_NAME
        return self
      end

      assign_tax_groups!
      @merchandise_lines = build_merchandise_lines
      @stored_value_issuances = build_stored_value_issuances
      @payments = build_payments
      @tender_balance_notes = tender_balance_notes_for_print
      @issued_balance_notes = issued_balance_notes_for_print
      verify_total!
      self
    end

    # Backward-compatible alias for tests and callers expecting a single line list.
    def lines
      merchandise_lines
    end

    def tenders
      payments
    end

    def remaining_balance_notes
      tender_balance_notes + issued_balance_notes
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
      lines << "Ph: #{@store.phone}" if @store.phone.present?
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
      @transaction.completed_at.in_time_zone(zone).strftime("%-d %b %Y %-l:%M%P")
    end

    def identity_header
      Pos::ReceiptIdentity.header(
        store_number: @transaction.store_number_snapshot,
        register_number: @transaction.register_number_snapshot,
        receipt_sequence: @transaction.receipt_sequence
      )
    end

    def identity_compact_label
      store = Pos::ReceiptIdentity.pad(@transaction.store_number_snapshot, 3)
      register = Pos::ReceiptIdentity.pad(@transaction.register_number_snapshot, 2)
      trans = Pos::ReceiptIdentity.pad(@transaction.receipt_sequence, 7)
      "#{store} / #{register} / #{trans}"
    end

    def compact_reference
      @transaction.transaction_reference
    end

    def barcode_svg
      Pos::Code128.svg(compact_reference)
    end

    def customer_name
      @transaction.customer&.display_name
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

    def net_merchandise_cents
      merchandise_cents + discounts_cents + returns_cents
    end

    def activation_issuance_cents
      stored_value_issuances.select(&:activation).sum(&:amount_cents)
    end

    def reload_issuance_cents
      stored_value_issuances.reject(&:activation).sum(&:amount_cents)
    end

    def total_tax_cents
      @transaction.tax_cents - @transaction.return_tax_cents
    end

    def signed_net_cents
      @transaction.signed_net_cents
    end

    def show_merchandise_section?
      merchandise_lines.any?
    end

    def show_stored_value_section?
      stored_value_issuances.any?
    end

    def show_activation_section?
      stored_value_issuances.any?(&:activation)
    end

    def show_reload_section?
      stored_value_issuances.any? { |line| !line.activation }
    end

    def show_detail_totals?
      @transaction.discount_cents.positive? || @transaction.return_total_cents.positive? ||
        activation_issuance_cents != 0 || reload_issuance_cents != 0 ||
        @transaction.pos_transaction_lines.any?(&:return?)
    end

    def show_tax_section?
      tax_groups.any? && total_tax_cents != 0
    end

    def refund_total?
      signed_net_cents.negative?
    end

    def even_exchange?
      signed_net_cents.zero? && show_merchandise_section? &&
        @transaction.pos_transaction_lines.any?(&:return?)
    end

    def total_label
      return "REFUND TOTAL" if refund_total?
      return "NET TOTAL" if even_exchange?

      "TOTAL DUE"
    end

    def total_display_cents
      signed_net_cents.abs
    end

    def show_payments_section?
      signed_net_cents != 0 && payments.any?
    end

    def show_issued_balances_section?
      issued_balance_notes.any?
    end

    def items_sold
      ordinary_lines.select(&:sale?).sum(&:quantity)
    end

    def items_returned
      ordinary_lines.select(&:return?).sum(&:quantity)
    end

    def show_item_counts?
      !post_void_reversal? && (items_sold.positive? || items_returned.positive?)
    end

    def item_counts_label
      sold = items_sold.positive?
      returned = items_returned.positive?
      if sold && returned
        "Items Sold / Returned:"
      elsif sold
        "Items Sold:"
      else
        "Items Returned"
      end
    end

    def item_counts_value
      sold = items_sold.positive?
      returned = items_returned.positive?
      if sold && returned
        "#{items_sold} / #{items_returned}"
      elsif sold
        items_sold.to_s
      else
        items_returned.to_s
      end
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

      @tax_groups = ordered.each_with_index.map do |(_key, members), index|
        letter = LETTERS.fetch(index)
        @indicator_by_key[[ members.first.last.store_tax_id, members.first.last.rate_percent ]] = letter
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

    def build_merchandise_lines
      @transaction.pos_transaction_lines.map { |line| build_merchandise_line(line) }
    end

    def build_merchandise_line(line)
      snapshot = line.merchandise_snapshot.is_a?(Hash) ? line.merchandise_snapshot : {}
      identifier_value = snapshot["unit_identifier"].presence || snapshot["sku"].presence
      identifier_label =
        if snapshot["unit_identifier"].present?
          "Unit"
        elsif snapshot["sku"].present?
          "SKU"
        end
      has_discount = line.manual_discount_cents.to_i.positive?
      MerchandiseLine.new(
        kind_banner: line_banner(line),
        description: snapshot["description"].presence || "Description unavailable",
        amount_cents: signed_amount(line, line.net_merchandise_amount_cents),
        tax_indicators: tax_indicators_for(line),
        identifier_label: identifier_label,
        identifier_value: identifier_value,
        condition: merchandise_detail(snapshot),
        quantity: line.quantity,
        unit_price_cents: line.selling_unit_price_cents,
        show_quantity_detail: line.quantity > 1,
        regular_price_cents: has_discount ? line.extended_selling_amount_cents : nil,
        discount_cents: has_discount ? -line.manual_discount_cents : 0,
        discount_label: discount_label(line),
        original_reference: original_reference_for(line),
        unlinked: line.unlinked_return?
      )
    end

    def build_stored_value_issuances
      @transaction.pos_stored_value_issuances.ordered.map do |issuance|
        program_name = issuance.gift_card_program&.name.presence || "Store Gift Card"
        masked = issuance.masked_card_snapshot
        StoredValueIssuanceLine.new(
          title: program_name,
          masked_card: masked,
          amount_cents: issuance.post_void_generated? ? -issuance.amount_cents : issuance.amount_cents,
          activation: issuance.activation?
        )
      end
    end

    def line_banner(line)
      return if line.post_void_generated?
      return "UNLINKED RETURN" if line.unlinked_return?
      return "RETURN" if line.return?

      nil
    end

    def merchandise_detail(snapshot)
      detail = snapshot["variant_detail"].presence
      return detail if detail.present?

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
      "Discount (#{formatted}%):"
    end

    def original_reference_for(line)
      return unless line.linked_return?

      original = line.original_transaction_line&.pos_transaction
      return if original.blank?

      original.transaction_reference
    end

    def build_payments
      return [] if signed_net_cents.zero?

      @transaction.pos_tenders.sort_by(&:tender_number).map do |tender|
        label = tender.direction == "refund" ? "#{tender.tender_name} Refund" : tender.tender_name
        inline_balance = inline_balance_note_for_tender(tender)
        if pos_cash_payment?(tender)
          PaymentLine.new(
            label: label,
            amount_cents: tender.amount_cents,
            cash_tendered_cents: tender.amount_presented_cents,
            cash_applied_cents: tender.amount_cents,
            change_cents: tender.change_cents,
            inline_balance_note: inline_balance
          )
        else
          PaymentLine.new(
            label: label,
            amount_cents: tender.amount_cents,
            cash_tendered_cents: nil,
            cash_applied_cents: nil,
            change_cents: nil,
            inline_balance_note: inline_balance
          )
        end
      end
    end

    def pos_cash_payment?(tender)
      tender.cash? && tender.direction == "payment"
    end

    def inline_balance_note_for_tender(tender)
      detail = tender.stored_value_tender_detail
      return if detail.blank?

      balance_cents = balance_after_cents_for_tender(detail)
      return if balance_cents.nil?

      masked = masked_reference_for_tender(detail)
      BalanceNote.new(label: balance_label_for_tender(detail), masked_card: masked, balance_cents: balance_cents)
    end

    def tender_balance_notes_for_print
      payments.filter_map(&:inline_balance_note)
    end

    def issued_balance_notes_for_print
      notes = []
      @transaction.pos_stored_value_issuances.ordered.each do |issuance|
        card = issuance.gift_card
        next unless card

        balance_cents = balance_after_cents_for_issuance(issuance)
        next if balance_cents.nil?

        notes << BalanceNote.new(
          label: "New Balance",
          masked_card: issuance.masked_card_snapshot.presence || card.masked_number,
          balance_cents: balance_cents
        )
      end
      notes
    end

    def balance_after_cents_for_issuance(issuance)
      account_id = issuance.gift_card&.stored_value_account_id
      balance_after_cents_for_operation(issuance.stored_value_operation, account_id)
    end

    def balance_after_cents_for_tender(detail)
      account_id = detail.stored_value_account_id || detail.gift_card&.stored_value_account_id
      balance_after_cents_for_operation(detail.stored_value_operation, account_id)
    end

    def balance_after_cents_for_operation(operation, account_id)
      return if operation.blank? || account_id.blank?

      entry = operation.stored_value_entries.find_by(stored_value_account_id: account_id)
      entry&.balance_after_cents
    end

    def masked_reference_for_tender(detail)
      detail.masked_card_snapshot.presence ||
        detail.gift_card&.masked_number ||
        "Store Credit"
    end

    def balance_label_for_tender(detail)
      detail.new_gift_card? ? "New Balance" : "Remaining Balance"
    end

    def verify_total!
      tax_sum = @tax_groups.sum(&:tax_cents)
      unless tax_sum == total_tax_cents
        raise Pos::Error, "receipt tax components do not equal persisted tax"
      end

      computed = net_merchandise_cents + total_tax_cents + @transaction.stored_value_issuance_cents.to_i
      return if computed == signed_net_cents

      raise Pos::Error, "receipt total does not equal signed_net_cents"
    end
  end
end
