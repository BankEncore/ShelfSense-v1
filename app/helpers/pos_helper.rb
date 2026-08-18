# frozen_string_literal: true

module PosHelper
  def pos_line_description(line)
    snapshot = line.merchandise_snapshot
    if snapshot.is_a?(Hash) && snapshot["description"].present?
      pos_snapshot_line_description(snapshot)
    else
      pos_live_line_description(line)
    end
  end

  def format_store_timestamp(time, store)
    return if time.blank?

    zone = ActiveSupport::TimeZone[store.timezone] || ActiveSupport::TimeZone["UTC"]
    time.in_time_zone(zone).strftime("%Y-%m-%d %H:%M")
  end

  def pos_receipt_print_header(transaction)
    Pos::ReceiptIdentity.header(
      store_number: transaction.store_number_snapshot,
      register_number: transaction.register_number_snapshot,
      receipt_sequence: transaction.receipt_sequence
    )
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

  def pos_optional_money_cents(cents)
    return "not captured" if cents.nil?

    format_money_cents(cents)
  end

  def pos_mode_label(mode)
    {
      "sale_entry" => "SALE ENTRY",
      "quantity" => "QUANTITY",
      "tender" => "CASH TENDER",
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

  def pos_live_line_description(line)
    variant = line.product_variant
    if line.unit_line?
      parts = [ variant.product.name, variant.merchandise_condition&.code, line.inventory_unit&.unit_identifier ]
      parts.compact.join("  ")
    else
      "#{variant.product.name}  #{variant.sku}"
    end
  end
end
