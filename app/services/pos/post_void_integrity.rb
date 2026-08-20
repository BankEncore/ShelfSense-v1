# frozen_string_literal: true

module Pos
  class PostVoidIntegrity
    CONFLICT = "Post-void cannot be completed because subsequent inventory activity conflicts with the original transaction."

    def self.verify!(source:, reversal:)
      new(source: source, reversal: reversal).verify!
    end

    def initialize(source:, reversal:)
      @source = source
      @reversal = reversal
    end

    def verify!
      raise Pos::Error, "reversal is not a post-void of the source" unless @reversal.post_void_of_transaction_id == @source.id
      raise Pos::Error, "post-void signed net must negate the source" unless @reversal.signed_net_cents == -@source.signed_net_cents

      verify_lines!
      verify_tenders!
      verify_no_sale_actions!
    end

    private

    def verify_lines!
      source_lines = @source.pos_transaction_lines.order(:line_number, :id).to_a
      reversal_lines = @reversal.pos_transaction_lines.order(:line_number, :id).to_a
      raise Pos::Error, "post-void must reverse every source line" unless source_lines.size == reversal_lines.size

      used_source_ids = reversal_lines.filter_map(&:post_void_source_line_id)
      raise Pos::Error, "post-void line lineage is incomplete" unless used_source_ids.sort == source_lines.map(&:id).sort

      reversal_lines.each do |line|
        source = line.post_void_source_line
        raise Pos::Error, "post-void line is missing the source line" if source.nil?
        raise Pos::Error, "post-void line direction must reverse the source" unless opposite_direction?(source, line)
        %i[
          quantity product_variant_id inventory_unit_id
          reference_unit_price_cents selling_unit_price_cents
          extended_selling_amount_cents manual_discount_cents
          net_merchandise_amount_cents line_tax_cents line_total_cents tax_class_id
        ].each do |attribute|
          unless line.public_send(attribute) == source.public_send(attribute)
            raise Pos::Error, "post-void line does not match the source"
          end
        end
        unless line.merchandise_snapshot == source.merchandise_snapshot
          raise Pos::Error, "post-void line does not match the source"
        end
        verify_tax_components!(source, line)
        raise Pos::Error, "post-void lines cannot have return reasons" if line.return_reason_code.present?
        raise Pos::Error, "post-void lines cannot be linked returns" if line.original_transaction_line_id.present?
      end
    end

    def verify_tax_components!(source, line)
      source_components = source.pos_line_tax_components.order(:calculation_order, :store_tax_id).map(&method(:component_tuple))
      reversal_components = line.pos_line_tax_components.order(:calculation_order, :store_tax_id).map(&method(:component_tuple))
      raise Pos::Error, "post-void tax components do not match the source" unless source_components == reversal_components
    end

    def component_tuple(component)
      [
        component.store_tax_id,
        component.rate_percent,
        component.applies,
        component.taxable_basis_cents,
        component.tax_cents,
        component.calculation_order
      ]
    end

    def verify_tenders!
      source_tenders = @source.pos_tenders.ordered.to_a
      reversal_tenders = @reversal.pos_tenders.ordered.to_a
      raise Pos::Error, "post-void must reverse every source tender" unless source_tenders.size == reversal_tenders.size

      used_ids = reversal_tenders.filter_map(&:post_void_source_tender_id)
      raise Pos::Error, "post-void tender lineage is incomplete" unless used_ids.sort == source_tenders.map(&:id).sort

      reversal_tenders.each do |tender|
        source = tender.post_void_source_tender
        raise Pos::Error, "post-void tender is missing the source tender" if source.nil?
        raise Pos::Error, "post-void tender direction must reverse the source" unless opposite_tender?(source, tender)
        unless tender.amount_cents == source.amount_cents &&
               tender.tender_type == source.tender_type &&
               tender.behavioral_category == source.behavioral_category
          raise Pos::Error, "post-void tender does not match the source"
        end
      end
    end

    def verify_no_sale_actions!
      actions = @reversal.pos_controlled_actions.to_a
      raise Pos::Error, "post-void is missing the post_void fact" unless actions.one? { |action| action.action_type == "post_void" }
      extras = actions.reject { |action| action.action_type == "post_void" }
      raise Pos::Error, "post-void cannot copy sale or unlinked controlled actions" if extras.any?
    end

    def opposite_direction?(source, line)
      (source.sale? && line.return?) || (source.return? && line.sale?)
    end

    def opposite_tender?(source, tender)
      (source.direction == "payment" && tender.direction == "refund") ||
        (source.direction == "refund" && tender.direction == "payment")
    end
  end
end
