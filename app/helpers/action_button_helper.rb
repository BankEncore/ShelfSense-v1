# frozen_string_literal: true

module ActionButtonHelper
  STYLES = %w[solid outline ghost link].freeze
  SIZES = %w[small standard large].freeze
  INTENTS_BY_STYLE = {
    "solid" => %w[brand warning danger].freeze,
    "outline" => %w[brand neutral warning danger].freeze,
    "ghost" => %w[neutral].freeze,
    "link" => %w[neutral].freeze
  }.freeze

  NAVIGATION_ONLY_KEYS = %i[target rel download href].freeze

  def action_link_to(label, url, style:, intent:, size: :standard, disabled: false, **html_options)
    raise ArgumentError, "action_link_to does not accept method:" if option_key?(html_options, :method)

    classes = action_button_class_list(style:, intent:, size:, html_options:)
    ensure_accessible_name!(label, html_options)

    if disabled
      span_options = html_options.except(*NAVIGATION_ONLY_KEYS, *NAVIGATION_ONLY_KEYS.map(&:to_s))
      span_options = without_executable_bindings!(span_options)
      content_tag(:span, label, span_options.merge(class: classes, "aria-disabled": true))
    else
      link_to(label, url, html_options.merge(class: classes))
    end
  end

  def action_button_to(label, url, style:, intent:, size: :standard, method:, form: {}, **html_options)
    raise ArgumentError, "action_button_to requires method:" if method.nil?

    classes = action_button_class_list(style:, intent:, size:, html_options:, form_options: form)
    ensure_accessible_name!(label, html_options)

    button_to(label, url, html_options.merge(method:, form:, class: classes))
  end

  def action_submit(form_builder, label, style:, intent:, size: :standard, **html_options)
    raise ArgumentError, "action_submit does not accept a URL" if option_key?(html_options, :url)
    raise ArgumentError, "action_submit does not accept method:" if option_key?(html_options, :method)

    classes = action_button_class_list(style:, intent:, size:, html_options:)
    ensure_accessible_name!(label, html_options)

    form_builder.button(label, html_options.merge(class: classes))
  end

  def action_button(label, style:, intent:, size: :standard, type: :button, **html_options)
    raise ArgumentError, "action_button only accepts type: :button" unless type.to_sym == :button

    classes = action_button_class_list(style:, intent:, size:, html_options:)
    ensure_accessible_name!(label, html_options)

    button_tag(label, html_options.merge(type: "button", class: classes))
  end

  private

  def action_button_class_list(style:, intent:, size:, html_options:, form_options: nil)
    reject_caller_classes!(html_options)
    reject_caller_classes!(form_options) if form_options

    style_key = normalize_token!(style, STYLES, "style")
    intent_key = normalize_token!(intent, INTENTS_BY_STYLE.fetch(style_key), "intent")
    size_key = normalize_token!(size, SIZES, "size")

    "btn btn--#{style_key} btn--#{intent_key} btn--#{size_key}"
  end

  def normalize_token!(value, allowed, name)
    key = value.to_s
    raise ArgumentError, "invalid #{name}: #{value.inspect}" unless allowed.include?(key)

    key
  end

  def reject_caller_classes!(options)
    return if options.nil?

    raise ArgumentError, "caller-supplied class is not allowed" if option_key?(options, :class)

    options.each_key do |key|
      key_s = key.to_s
      next unless key_s.include?("class") && key_s != "class"

      raise ArgumentError, "class-related option #{key.inspect} is not allowed"
    end
  end

  def ensure_accessible_name!(label, html_options)
    return if label_present?(label)

    aria = html_options[:aria] || html_options["aria"] || {}
    aria_label = aria[:label] || aria["label"] ||
      html_options[:"aria-label"] || html_options["aria-label"]
    return if aria_label.present?

    raise ArgumentError, "icon-only or blank action requires aria-label"
  end

  def label_present?(label)
    case label
    when String then label.strip.present?
    else label.present?
    end
  end

  def option_key?(options, key)
    options.key?(key) || options.key?(key.to_s)
  end

  def without_executable_bindings!(options)
    return options unless options.is_a?(Hash)

    stripped = options.deep_dup
    stripped.delete(:action)
    stripped.delete("action")
    stripped.delete(:"data-action")
    stripped.delete("data-action")

    data = stripped[:data] || stripped["data"]
    if data.is_a?(Hash)
      data = data.except(:action, "action", :controller, "controller")
      if data.empty?
        stripped.delete(:data)
        stripped.delete("data")
      elsif stripped.key?(:data)
        stripped[:data] = data
      else
        stripped["data"] = data
      end
    end

    stripped
  end
end
