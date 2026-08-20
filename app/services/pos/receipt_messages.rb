# frozen_string_literal: true

module Pos
  class ReceiptMessages
    def self.header(store)
      new(store).header
    end

    def self.footer(store)
      new(store).footer
    end

    def initialize(store)
      @store = store
    end

    def header
      message_for(@store.receipt_header_mode, @store.receipt_header, :default_receipt_header)
    end

    def footer
      message_for(@store.receipt_footer_mode, @store.receipt_footer, :default_receipt_footer)
    end

    private

    def message_for(mode, custom, default_attr)
      case mode
      when "none"
        nil
      when "custom"
        custom.presence
      else
        SystemSettings.current.public_send(default_attr).presence
      end
    end
  end
end
