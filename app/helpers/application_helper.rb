# frozen_string_literal: true

module ApplicationHelper
  STATUS_SCHEMES = {
    product_variant: {
      "draft" => "draft",
      "active" => "active",
      "discontinued" => "discontinued"
    }.freeze,
    configuration: {
      "active" => "active",
      "inactive" => "inactive"
    }.freeze,
    customer_request: CustomerRequest::STATUSES.index_with { |status|
      CustomerRequest::ACTIVE_STATUSES.include?(status) ? "active" : "inactive"
    }.freeze
  }.freeze

  def format_money_cents(cents, currency_prefix: "$")
    return missing_value if cents.nil?

    sign = cents.negative? ? "-" : ""
    absolute = cents.abs
    dollars = absolute / 100
    remainder = absolute % 100
    "#{sign}#{currency_prefix}#{dollars}.#{format("%02d", remainder)}"
  end

  def format_signed_money_cents(cents, currency_prefix: "$")
    return missing_value if cents.nil?
    return format_money_cents(cents, currency_prefix: currency_prefix) unless cents.positive?

    "+#{format_money_cents(cents, currency_prefix: currency_prefix)}"
  end

  def money_field_value(cents)
    return if cents.nil?

    sign = cents.negative? ? "-" : ""
    absolute = cents.abs
    "#{sign}#{absolute / 100}.#{format("%02d", absolute % 100)}"
  end

  def missing_value(label = "Not provided")
    content_tag(:span, label, class: "missing-value")
  end

  def format_timestamp(time)
    return missing_value if time.blank?

    time.in_time_zone.strftime("%Y-%m-%d %H:%M %Z")
  end

  def format_date(date)
    return missing_value if date.blank?

    date.to_date.iso8601
  end

  # scheme: :product_variant or :configuration
  def status_badge(status, scheme:)
    mapping = STATUS_SCHEMES.fetch(scheme.to_sym)
    key = status.to_s
    raise ArgumentError, "unknown status #{status.inspect} for scheme #{scheme}" unless mapping.key?(key)

    css = mapping.fetch(key)
    content_tag(:span, key.humanize, class: "status-badge status-badge--#{css}")
  end

  def configuration_status_badge(active)
    status_badge(active ? "active" : "inactive", scheme: :configuration)
  end
end
