# frozen_string_literal: true

module PosHelper
  def pos_line_description(line)
    snapshot = line.merchandise_snapshot
    if snapshot.is_a?(Hash) && snapshot["description"].present?
      sku = snapshot["sku"]
      sku.present? ? "#{snapshot["description"]}  #{sku}" : snapshot["description"]
    else
      variant = line.product_variant
      "#{variant.product.name}  #{variant.sku}"
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
    description = snapshot.is_a?(Hash) ? snapshot["description"] : nil
    description.presence || "Description unavailable"
  end

  def pos_padded_store_number(store)
    Pos::ReceiptIdentity.pad(store.store_number, 3)
  end

  def pos_padded_register_number(register)
    Pos::ReceiptIdentity.pad(register.register_number, 2)
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
end
