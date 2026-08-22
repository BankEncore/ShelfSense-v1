# frozen_string_literal: true

class StoreDocumentSequence < ApplicationRecord
  DOCUMENT_KINDS = %w[customer_request order purchase_order purchase_receipt].freeze

  belongs_to :store

  validates :document_kind, presence: true, inclusion: { in: DOCUMENT_KINDS }
  validates :next_value, numericality: { only_integer: true, greater_than: 0 }
  validates :document_kind, uniqueness: { scope: :store_id }

  # Atomically allocates the next store-scoped document number for +document_kind+.
  # Must run inside the caller's transaction when the number is persisted on a document.
  def self.next_number!(store:, document_kind:)
    raise ArgumentError, "unsupported document kind" unless DOCUMENT_KINDS.include?(document_kind.to_s)

    sequence = lock_or_create!(store: store, document_kind: document_kind.to_s)
    number = sequence.next_value
    sequence.update!(next_value: number + 1)
    number
  end

  def self.lock_or_create!(store:, document_kind:)
    existing = uncached { lock.find_by(store_id: store.id, document_kind: document_kind) }
    return existing if existing

    create!(store: store, document_kind: document_kind, next_value: 1)
  rescue ActiveRecord::RecordNotUnique
    uncached { lock.find_by!(store_id: store.id, document_kind: document_kind) }
  end
  private_class_method :lock_or_create!
end
