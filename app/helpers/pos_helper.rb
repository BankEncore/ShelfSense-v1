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
