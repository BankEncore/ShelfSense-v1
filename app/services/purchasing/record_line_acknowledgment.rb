# frozen_string_literal: true

module Purchasing
  class RecordLineAcknowledgment
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      purchase_order_line:,
      actor:,
      confirmed_quantity: :__omit__,
      backordered_quantity: :__omit__,
      expected_on: :__omit__,
      supplier_reference: :__omit__,
      notes: :__omit__,
      expected_lock_version: nil,
      correlation_id: nil
    )
      @purchase_order_line = purchase_order_line
      @actor = actor
      @confirmed_quantity = confirmed_quantity
      @backordered_quantity = backordered_quantity
      @expected_on = expected_on
      @supplier_reference = supplier_reference
      @notes = notes
      @expected_lock_version = expected_lock_version
      @correlation_id = correlation_id || SecureRandom.uuid_v7
    end

    def call
      PurchaseOrderLine.transaction do
        raise Purchasing::Error, "actor is required" if @actor.blank?

        line = PurchaseOrderLine.lock.find(@purchase_order_line.id)
        po = PurchaseOrder.lock.find(line.purchase_order_id)
        raise Purchasing::Error, "acknowledgments require a sent purchase order" unless po.sent? || po.closed?

        state = PurchaseOrderLineState.lock.find_by(purchase_order_line_id: line.id)
        raise Purchasing::Error, "line state is missing; send the purchase order first" if state.blank?

        assert_lock_version!(state)
        before = snapshot(state)

        unless @confirmed_quantity == :__omit__
          qty = @confirmed_quantity.presence && Integer(@confirmed_quantity)
          raise Purchasing::Error, "confirmed quantity must be nonnegative" if qty && qty.negative?

          state.confirmed_quantity = qty
        end
        unless @backordered_quantity == :__omit__
          qty = Integer(@backordered_quantity)
          raise Purchasing::Error, "backordered quantity must be nonnegative" if qty.negative?

          state.backordered_quantity = qty
        end
        state.expected_on = parse_date(@expected_on) unless @expected_on == :__omit__
        state.supplier_reference = @supplier_reference unless @supplier_reference == :__omit__
        state.notes = @notes unless @notes == :__omit__
        state.save!

        Audit::Recorder.record!(
          action: "purchase_orders.record_acknowledgment",
          outcome: "succeeded",
          actor_user: @actor,
          store: po.store,
          subject: line,
          correlation_id: @correlation_id,
          before_values: before,
          after_values: snapshot(state)
        )

        state
      end
    end

    private

    def assert_lock_version!(state)
      return if @expected_lock_version.nil?
      return if state.lock_version == @expected_lock_version.to_i

      raise ActiveRecord::StaleObjectError.new(state, "update")
    end

    def parse_date(value)
      return if value.blank?
      return value if value.is_a?(Date)

      Date.parse(value.to_s)
    rescue ArgumentError
      raise Purchasing::Error, "expected_on is not a valid date"
    end

    def snapshot(state)
      {
        confirmed_quantity: state.confirmed_quantity,
        backordered_quantity: state.backordered_quantity,
        expected_on: state.expected_on,
        supplier_reference: state.supplier_reference,
        notes: state.notes
      }
    end
  end
end
