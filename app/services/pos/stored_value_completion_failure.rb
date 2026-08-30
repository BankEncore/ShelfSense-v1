# frozen_string_literal: true

module Pos
  # Raised when completion-time stored-value revalidation refuses the working
  # transaction. Carries the affected working record so the workspace can select
  # it in Completion Failed / Tender Review instead of clearing anything.
  class StoredValueCompletionFailure < Error
    attr_reader :tender_id, :issuance_id

    def initialize(message, tender_id: nil, issuance_id: nil)
      super(message)
      @tender_id = tender_id
      @issuance_id = issuance_id
    end
  end
end
