# frozen_string_literal: true

module Bibliographic
  module ProductFormMapper
    module_function

    TEXT_MAP = {
      "hardcover" => "HC",
      "hard cover" => "HC",
      "hardback" => "HC",
      "hard bound" => "HC",
      "trade cloth" => "TC",
      "paperback" => "PB",
      "softcover" => "PB",
      "soft cover" => "PB",
      "softback" => "PB",
      "trade paper" => "TP",
      "trade paperback" => "TP",
      "mass market" => "MM",
      "mass market paperback" => "MM",
      "rack size" => "MM",
      "board book" => "BB",
      "boardbook" => "BB",
      "ebook" => "EB",
      "e-book" => "EB",
      "e book" => "EB",
      "electronic book" => "EB",
      "audio cd" => "CD",
      "compact disc" => "CD",
      "mp3 cd" => "CM",
      "mp3-cd" => "CM",
      "audio cd (mp3)" => "CM",
      "audiobook" => "AU",
      "audio book" => "AU",
      "audio" => "AU",
      "spiral" => "SP",
      "spiral bound" => "SP",
      "spiral binding" => "SP",
      "comb bound" => "CB",
      "comb" => "CB",
      "ring bound" => "RB",
      "ringbound" => "RB",
      "library binding" => "LB",
      "leather" => "LT",
      "leather bound" => "LT",
      "imitation leather" => "IL",
      "vinyl bound" => "VB",
      "loose-leaf" => "LL",
      "looseleaf" => "LL",
      "loose leaf" => "LL",
      "pop up" => "PO",
      "pop-up" => "PO",
      "bath book" => "BA",
      "bathbook" => "BA"
    }.freeze

    CODES = %w[
      AU BA BB BG BM BX CA CB CD CG CM CP CS DO EB GC GM HC IL LB LL LT
      MM MP MU OT PB PO PS PU RB SP TA TC TO TP TY VB
    ].freeze

    def code_for(raw)
      text = raw.to_s.unicode_normalize(:nfkc).strip.gsub(/\s+/, " ")
      return if text.blank?

      upper = text.upcase
      return upper if CODES.include?(upper)

      TEXT_MAP[text.downcase]
    end
  end
end
