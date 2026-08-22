# frozen_string_literal: true

module Purchasing
  class UpdateDraftPurchaseReceipt
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      purchase_receipt:,
      actor:,
      expected_lock_version: nil,
      received_at: :__omit__,
      supplier_document_number: :__omit__,
      supplier_document_date: :__omit__,
      freight_cents: :__omit__,
      handling_cents: :__omit__,
      supplier_tax_cents: :__omit__,
      miscellaneous_charges_cents: :__omit__,
      charge_notes: :__omit__,
      notes: :__omit__,
      correlation_id: nil
    )
      @receipt = purchase_receipt
      @actor = actor
      @expected_lock_version = expected_lock_version
      @received_at = received_at
      @supplier_document_number = supplier_document_number
      @supplier_document_date = supplier_document_date
      @freight_cents = freight_cents
      @handling_cents = handling_cents
      @supplier_tax_cents = supplier_tax_cents
      @miscellaneous_charges_cents = miscellaneous_charges_cents
      @charge_notes = charge_notes
      @notes = notes
      @correlation_id = correlation_id || SecureRandom.uuid_v7
    end

    def call
      raise Purchasing::Error, "actor is required" if @actor.blank?
      raise Purchasing::Error, "purchase receipt is required" if @receipt.blank?

      PurchaseReceipt.transaction do
        receipt = PurchaseReceipt.lock.find(@receipt.id)
        assert_lock_version!(receipt)
        raise Purchasing::Error, "only draft receipts can be edited" unless receipt.draft?

        before = snapshot(receipt)
        attrs = build_attrs(receipt)
        if attrs[:received_at].present? && attrs[:received_at] > Time.current + 1.second
          raise Purchasing::Error, "received_at cannot be in the future"
        end

        receipt.update!(attrs)
        after = snapshot(receipt)

        Audit::Recorder.record!(
          action: "purchase_receipts.update_draft",
          outcome: "succeeded",
          actor_user: @actor,
          store: receipt.store,
          subject: receipt,
          correlation_id: @correlation_id,
          before_values: before,
          after_values: after
        )

        receipt
      end
    end

    private

    def assert_lock_version!(receipt)
      return if @expected_lock_version.nil?
      return if receipt.lock_version == @expected_lock_version.to_i

      raise ActiveRecord::StaleObjectError.new(receipt, "update")
    end

    def build_attrs(receipt)
      attrs = {}
      attrs[:received_at] = @received_at if present_arg?(@received_at)
      if present_arg?(@supplier_document_number)
        attrs[:supplier_document_number] = @supplier_document_number.presence
      end
      if present_arg?(@supplier_document_date)
        attrs[:supplier_document_date] = @supplier_document_date.presence
      end
      attrs[:freight_cents] = @freight_cents.to_i if present_arg?(@freight_cents)
      attrs[:handling_cents] = @handling_cents.to_i if present_arg?(@handling_cents)
      attrs[:supplier_tax_cents] = @supplier_tax_cents.to_i if present_arg?(@supplier_tax_cents)
      if present_arg?(@miscellaneous_charges_cents)
        attrs[:miscellaneous_charges_cents] = @miscellaneous_charges_cents.to_i
      end
      attrs[:charge_notes] = @charge_notes if present_arg?(@charge_notes)
      attrs[:notes] = @notes if present_arg?(@notes)
      attrs
    end

    def present_arg?(value)
      value != :__omit__
    end

    def snapshot(receipt)
      {
        received_at: receipt.received_at,
        supplier_document_number: receipt.supplier_document_number,
        supplier_document_date: receipt.supplier_document_date,
        freight_cents: receipt.freight_cents,
        handling_cents: receipt.handling_cents,
        supplier_tax_cents: receipt.supplier_tax_cents,
        miscellaneous_charges_cents: receipt.miscellaneous_charges_cents,
        charge_notes: receipt.charge_notes,
        notes: receipt.notes
      }
    end
  end
end
