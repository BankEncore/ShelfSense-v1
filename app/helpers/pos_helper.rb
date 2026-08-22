# frozen_string_literal: true

module PosHelper
  CONTROLLED_ACTION_LABELS = {
    "price_override" => "Price override",
    "line_discount" => "Line discount",
    "tax_class_override" => "Tax Class override",
    "unlinked_return" => "Unlinked return",
    "post_void" => "Post-void"
  }.freeze

  def pos_line_description(line)
    snapshot = line.merchandise_snapshot
    if snapshot.is_a?(Hash) && snapshot["description"].present?
      pos_snapshot_line_description(snapshot)
    else
      pos_live_line_description(line)
    end
  end

  # Register basket title only (screen). Print and data-description keep pos_line_description.
  def pos_basket_line_title(line)
    snapshot = line.merchandise_snapshot
    title =
      if snapshot.is_a?(Hash) && snapshot["description"].present?
        snapshot["description"]
      else
        line.product_variant&.product&.name.presence || "Description unavailable"
      end
    prefix = line.pickup_line? ? "PICKUP · " : ""
    "#{prefix}#{title}"
  end

  # Secondary basket metadata from snapshot (preferred) or working-line fields.
  # Returns hashes: { text:, mono: } for identifier-like values.
  def pos_basket_line_metadata(line)
    snapshot = line.merchandise_snapshot
    if snapshot.is_a?(Hash) && snapshot["description"].present?
      pos_snapshot_basket_metadata(snapshot)
    else
      pos_live_basket_metadata(line)
    end
  end

  def format_store_timestamp(time, store)
    return if time.blank?

    zone = ActiveSupport::TimeZone[store.timezone] || ActiveSupport::TimeZone["UTC"]
    time.in_time_zone(zone).strftime("%Y-%m-%d %H:%M")
  end

  def pos_print_amount(cents)
    return if cents.nil?

    sign = cents.negative? ? "-" : ""
    absolute = cents.abs
    "#{sign}#{absolute / 100}.#{format("%02d", absolute % 100)}"
  end

  def pos_code128_svg(payload)
    Pos::Code128.svg(payload).html_safe
  end

  def pos_receipt_print_header(transaction)
    Pos::ReceiptIdentity.header(
      store_number: transaction.store_number_snapshot,
      register_number: transaction.register_number_snapshot,
      receipt_sequence: transaction.receipt_sequence
    )
  end

  def pos_cashier_name(transaction)
    transaction.cashier_name_snapshot.presence || "Not captured"
  end

  def pos_history_line_description(line)
    snapshot = line.merchandise_snapshot
    return "Description not captured" unless snapshot.is_a?(Hash)
    return "Description not captured" if snapshot["description"].blank?

    pos_snapshot_line_description(snapshot)
  end

  def pos_tender_summary(transaction)
    tenders = transaction.pos_tenders.sort_by(&:tender_number)
    refunds = tenders.any? { |tender| tender.direction == "refund" }
    tenders.map { |tender| pos_tender_label(tender, distinguish_cash_payment: refunds) }.join(" + ")
  end

  def pos_tender_label(tender, distinguish_cash_payment: true)
    if tender.direction == "refund"
      "#{tender.tender_name} refund"
    elsif tender.cash? && distinguish_cash_payment
      "#{tender.tender_name} payment"
    else
      tender.tender_name
    end
  end

  def pos_cash_payment?(tender)
    tender.cash? && tender.direction == "payment"
  end

  def pos_line_amount_cents(line)
    line.return? ? -line.extended_selling_amount_cents : line.extended_selling_amount_cents
  end

  def pos_line_discount_cents(line)
    line.return? ? line.manual_discount_cents : -line.manual_discount_cents
  end

  def pos_line_tax_cents(line)
    line.return? ? -line.line_tax_cents : line.line_tax_cents
  end

  def pos_history_query_params(search)
    {
      transaction_reference: search.transaction_reference,
      register_id: search.register_id,
      receipt_sequence: search.receipt_sequence,
      business_date: search.business_date
    }.compact_blank
  end

  def pos_applicable_tax_components(line)
    line.pos_line_tax_components.select(&:applies).sort_by(&:calculation_order)
  end

  def pos_print_line_description(line)
    snapshot = line.merchandise_snapshot
    return "Description unavailable" unless snapshot.is_a?(Hash)

    description = snapshot["description"].presence
    return "Description unavailable" if description.blank?
    return description unless snapshot["unit_identifier"].present?

    parts = [ description ]
    parts << snapshot["condition_code"] if snapshot["condition_code"].present?
    parts << snapshot["unit_identifier"]
    parts.join("  ")
  end

  def pos_padded_store_number(store)
    Pos::ReceiptIdentity.pad(store.store_number, 3)
  end

  def pos_padded_register_number(register)
    Pos::ReceiptIdentity.pad(register.register_number, 2)
  end

  def pos_padded_register_snapshot(number)
    Pos::ReceiptIdentity.pad(number, 2)
  end

  def pos_optional_money_cents(cents)
    return "not captured" if cents.nil?

    format_money_cents(cents)
  end

  def pos_optional_signed_money_cents(cents)
    return "not captured" if cents.nil?

    format_signed_money_cents(cents)
  end

  def pos_report_row_value(row)
    case row.format
    when :count
      row.cents.nil? ? "not captured" : row.cents
    when :optional_money
      pos_optional_money_cents(row.cents)
    when :optional_signed
      pos_optional_signed_money_cents(row.cents)
    when :signed
      format_signed_money_cents(row.cents)
    else
      format_money_cents(row.cents)
    end
  end

  def pos_line_kind_prefix(line)
    if line.post_void_generated?
      "POST-VOID"
    elsif line.return?
      "RETURN"
    end
  end

  def pos_post_void_merchandise_cents(transaction)
    transaction.subtotal_cents - transaction.return_subtotal_cents
  end

  def pos_post_void_discount_cents(transaction)
    transaction.discount_cents - transaction.return_discount_cents
  end

  def pos_post_void_tax_cents(transaction)
    transaction.tax_cents - transaction.return_tax_cents
  end

  def pos_unlinked_return_price_adjusted?(line)
    line.unlinked_return? && line.selling_unit_price_cents != line.reference_unit_price_cents
  end

  def pos_line_controlled?(line)
    line.price_overridden? || line.manually_discounted? || line.tax_class_overridden?
  end

  def pos_line_control_flags(line)
    flags = []
    flags << "Override" if line.price_overridden?
    flags << "Discount" if line.manually_discounted?
    flags << "Tax Class" if line.tax_class_overridden?
    flags.join(" · ")
  end

  def pos_controlled_action_label(action)
    CONTROLLED_ACTION_LABELS.fetch(action.action_type, action.action_type.tr("_", " "))
  end

  def pos_controlled_action_provenance(action)
    parts = [ pos_controlled_action_label(action), "Performed by #{action.performed_by_name_snapshot}" ]
    parts << "Approved by #{action.approved_by_name_snapshot}" if action.approved_by_name_snapshot.present?
    parts << action.reason_name_snapshot if action.reason_name_snapshot.present?
    parts << "Note #{action.reason_note}" if action.reason_note.present?
    parts.join(" · ")
  end

  def pos_mode_label(mode)
    {
      "sale_entry" => "SALE ENTRY",
      "quantity" => "QUANTITY",
      "tender" => "CASH TENDER",
      "refund" => "REFUND",
      "completion_pending" => "CASH TENDER",
      "completion_failed" => "CASH TENDER"
    }.fetch(mode, "SALE ENTRY")
  end

  def pos_snapshot_line_description(snapshot)
    parts = [ snapshot["description"] ]
    if snapshot["unit_identifier"].present?
      parts << snapshot["condition_code"] if snapshot["condition_code"].present?
      parts << snapshot["unit_identifier"]
    elsif snapshot["sku"].present?
      parts << snapshot["sku"]
    end
    parts.join("  ")
  end

  def pos_snapshot_basket_metadata(snapshot)
    parts = []
    condition = snapshot["condition_code"].presence || snapshot["condition_name"].presence
    parts << { text: condition, mono: false } if condition.present?
    if snapshot["unit_identifier"].present?
      parts << { text: snapshot["unit_identifier"], mono: true }
    elsif snapshot["sku"].present?
      parts << { text: snapshot["sku"], mono: true }
    end
    parts
  end

  def pos_live_basket_metadata(line)
    variant = line.product_variant
    return [] if variant.nil?

    parts = []
    if line.unit_line?
      code = variant.merchandise_condition&.code
      parts << { text: code, mono: false } if code.present?
      unit_id = line.inventory_unit&.unit_identifier
      parts << { text: unit_id, mono: true } if unit_id.present?
    elsif variant.sku.present?
      parts << { text: variant.sku, mono: true }
    end
    parts
  end

  def pos_live_line_description(line)
    variant = line.product_variant
    prefix = line.pickup_line? ? "PICKUP · " : ""
    if line.unit_line?
      parts = [ variant.product.name, variant.merchandise_condition&.code, line.inventory_unit&.unit_identifier ]
      "#{prefix}#{parts.compact.join("  ")}"
    else
      "#{prefix}#{variant.product.name}  #{variant.sku}"
    end
  end
end
