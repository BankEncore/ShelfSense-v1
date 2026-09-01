# frozen_string_literal: true

module AdminPageHelper
  ADMIN_PAGE_WIDTH_CLASSES = {
    narrow: "app-content--narrow",
    standard: "app-content--standard",
    wide: "app-content--wide",
    workspace: "app-content--workspace"
  }.freeze

  def capture_admin_page_width!(width)
    raise ArgumentError, "Admin page width has already been set" if content_for?(:admin_page_width)

    normalized = width.to_s.to_sym
    css_class = ADMIN_PAGE_WIDTH_CLASSES.fetch(normalized) do
      raise ArgumentError,
        "Unknown Admin page width #{width.inspect}; expected one of: " \
        "#{ADMIN_PAGE_WIDTH_CLASSES.keys.join(", ")}"
    end

    content_for(:admin_page_width, css_class, flush: true)
  end
end
