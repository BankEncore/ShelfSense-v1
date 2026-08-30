# frozen_string_literal: true

module Pos
  # Changing an issuance changes the transaction total, so every applied tender
  # must be cleared. The cashier confirms that against the current basis first;
  # the working tenders are never cleared silently.
  module IssuanceTenderClear
    module_function

    def require_confirmation!(transaction, confirmed:)
      return if transaction.pos_tenders.empty?
      return if confirmed

      raise Pos::Error,
            "changing gift cards changes the amount due, so the applied tenders must be cleared first — " \
            "confirm clearing them or Return to Sale"
    end

    def clear!(transaction)
      tenders = transaction.pos_tenders.ordered.to_a
      return [] if tenders.empty?

      removed_ids = tenders.map(&:id)
      tenders.each(&:destroy!)
      transaction.pos_tenders.reload
      removed_ids
    end
  end
end
