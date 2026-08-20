# frozen_string_literal: true

module Pos
  class Code128
    PATTERNS = %w[
      212222 222122 222221 121223 121322 131222 122213 122312 132212 221213
      221312 231212 112232 122132 122231 113222 123122 123221 223211 221132
      221231 213212 223112 312131 311222 321122 321221 312212 322112 322211
      212123 212321 232121 111323 131123 131321 112313 132113 132311 211313
      231113 231311 112133 112331 132131 113123 113321 133121 313121 211331
      231131 213113 213311 213131 311123 311321 331121 312113 312311 332111
      314111 221411 431111 111224 111422 121124 121421 141122 141221 112214
      112412 122114 122411 142112 142211 241211 221114 413111 241112 134111
      111242 121142 121241 114212 124112 124211 411212 421112 421211 212141
      214121 412121 111143 111341 131141 114113 114311 411113 411311 113141
      114131 311141 411131 211412 211214 211232
    ].freeze
    START_B = 104
    STOP = "2331112"

    def self.svg(payload, module_width: 1, height: 40)
      new(payload).svg(module_width: module_width, height: height)
    end

    def initialize(payload)
      @payload = payload.to_s
      raise ArgumentError, "barcode payload is required" if @payload.blank?
      @payload.each_char do |char|
        raise ArgumentError, "barcode payload is not Code 128 B" if char.ord < 32 || char.ord > 126
      end
    end

    def svg(module_width: 1, height: 40)
      bits = bar_widths
      quiet = 10 * module_width
      content_width = bits.sum * module_width
      width = content_width + (quiet * 2)
      x = quiet
      bars = +""
      bits.each_with_index do |w, index|
        bar_width = w * module_width
        bars << %(<rect x="#{x}" y="0" width="#{bar_width}" height="#{height}"/>) if index.even?
        x += bar_width
      end

      %(<svg xmlns="http://www.w3.org/2000/svg" role="img" aria-label="#{escape(@payload)}" viewBox="0 0 #{width} #{height}" width="#{width}" height="#{height}">#{bars}</svg>)
    end

    private

    def bar_widths
      values = [ START_B ]
      values.concat(@payload.chars.map { |char| char.ord - 32 })
      checksum = values.each_with_index.sum { |value, index| value * [ 1, index ].max } % 103
      encoded = values + [ checksum ]
      encoded.flat_map { |value| PATTERNS.fetch(value).chars.map(&:to_i) } + STOP.chars.map(&:to_i)
    end

    def escape(text)
      text.gsub("&", "&amp;").gsub('"', "&quot;").gsub("<", "&lt;").gsub(">", "&gt;")
    end
  end
end
