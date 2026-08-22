# frozen_string_literal: true

module Purchasing
  class CreateDraftPurchaseReceipt
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      store:,
      supplier:,
      actor:,
      received_at: nil,
      supplier_document_number: nil,
      supplier_document_date: nil,
      freight_cents: 0,
      handling_cents: 0,
      supplier_tax_cents: 0,
      miscellaneous_charges_cents: 0,
      charge_notes: nil,
      notes: nil,
      correlation_id: nil
    )
      @store = store
      @supplier = supplier
      @actor = actor
      @received_at = received_at
      @supplier_document_number = supplier_document_number
      @supplier_document_date = supplier_document_date
      @freight_cents = freight_cents.to_i
      @handling_cents = handling_cents.to_i
      @supplier_tax_cents = supplier_tax_cents.to_i
      @miscellaneous_charges_cents = miscellaneous_charges_cents.to_i
      @charge_notes = charge_notes
      @notes = notes
      @correlation_id = correlation_id || SecureRandom.uuid_v7
    end

    def call
      raise Purchasing::Error, "actor is required" if @actor.blank?
      raise Purchasing::Error, "store is required" if @store.blank?
      raise Purchasing::Error, "supplier is required" if @supplier.blank?
      raise Purchasing::Error, "supplier is inactive" unless @supplier.active?

      received_at = @received_at.presence || Time.current
      raise Purchasing::Error, "received_at cannot be in the future" if received_at > Time.current + 1.second

      PurchaseReceipt.transaction do
        receipt = PurchaseReceipt.create!(
          store: @store,
          supplier: @supplier,
          status: "draft",
          received_at: received_at,
          supplier_document_number: @supplier_document_number.presence,
          supplier_document_date: @supplier_document_date.presence,
          freight_cents: @freight_cents,
          handling_cents: @handling_cents,
          supplier_tax_cents: @supplier_tax_cents,
          miscellaneous_charges_cents: @miscellaneous_charges_cents,
          charge_notes: @charge_notes,
          notes: @notes
        )

        Audit::Recorder.record!(
          action: "purchase_receipts.create_draft",
          outcome: "succeeded",
          actor_user: @actor,
          store: @store,
          subject: receipt,
          correlation_id: @correlation_id,
          after_values: {
            supplier_id: @supplier.id,
            status: receipt.status,
            received_at: receipt.received_at
          }
        )

        receipt
      end
    end
  end
end
