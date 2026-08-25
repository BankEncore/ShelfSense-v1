# frozen_string_literal: true

module ProductForms
  module Catalog
    module_function

    SEEDS = [
      [ "AU", "Audio (format not specified)" ],
      [ "BA", "Bathbook" ],
      [ "BB", "Board Book" ],
      [ "BG", "Board Game" ],
      [ "BM", "Bookmark" ],
      [ "BX", "Box or Slipcase" ],
      [ "CA", "Wall Calendar" ],
      [ "CB", "Comb Bound" ],
      [ "CD", "Audio CD" ],
      [ "CG", "Clothing" ],
      [ "CM", "Audio CD (MP3)" ],
      [ "CP", "Box Calendar (Page-a-Day)" ],
      [ "CS", "Cards (flash or taro)" ],
      [ "DO", "Doll" ],
      [ "EB", "E-Book" ],
      [ "GC", "Greeting Card" ],
      [ "GM", "Game" ],
      [ "HC", "Hardcover" ],
      [ "IL", "Imitation Leather Bound" ],
      [ "LB", "Library Binding" ],
      [ "LL", "Loose-leaf" ],
      [ "LT", "Leather Bound" ],
      [ "MM", "Mass Market (Paperback)" ],
      [ "MP", "Sheet Map" ],
      [ "MU", "Mug" ],
      [ "OT", "Other" ],
      [ "PB", "Paperback" ],
      [ "PO", "Pop Up" ],
      [ "PS", "Posters/Prints" ],
      [ "PU", "Puzzle" ],
      [ "RB", "Ring Bound" ],
      [ "SP", "Spiral Binding" ],
      [ "TA", "Tableware" ],
      [ "TC", "Trade Cloth (Hardcover)" ],
      [ "TO", "Totebag" ],
      [ "TP", "Trade Paper (Paperback)" ],
      [ "TY", "Toy" ],
      [ "VB", "Vinyl Bound" ]
    ].freeze

    def seed!
      SEEDS.each_with_index do |(code, name), index|
        form = ProductForm.find_or_initialize_by(code: code)
        next unless form.new_record?

        form.name = name
        form.active = true
        form.display_order = (index + 1) * 10
        form.save!
      end
    end
  end
end
