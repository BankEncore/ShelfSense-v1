# frozen_string_literal: true

class PosOperation < ApplicationRecord
  STATUSES = %w[in_flight completed failed].freeze
  COMMAND_TYPE = "pos.complete_transaction"
  POST_VOID_COMMAND_TYPE = "pos.post_void_transaction"
  REMOVE_WORKING_TENDER_COMMAND_TYPE = "pos.remove_working_tender"
  REPLACE_WORKING_TENDER_COMMAND_TYPE = "pos.replace_working_tender"
  RETURN_TO_SALE_CLEAR_TENDERS_COMMAND_TYPE = "pos.return_to_sale_clear_tenders"
  ADD_WORKING_STORED_VALUE_TENDER_COMMAND_TYPE = "pos.add_working_stored_value_tender"
  ADD_WORKING_STORED_VALUE_REFUND_TENDER_COMMAND_TYPE = "pos.add_working_stored_value_refund_tender"
  ADD_WORKING_ISSUANCE_COMMAND_TYPE = "pos.add_working_issuance"
  REMOVE_WORKING_ISSUANCE_COMMAND_TYPE = "pos.remove_working_issuance"
  REPLACE_WORKING_ISSUANCE_COMMAND_TYPE = "pos.replace_working_issuance"
  FACT_TYPE = "pos.transaction_completed"
  REMOVE_WORKING_TENDER_FACT_TYPE = "pos.working_tender_removed"
  REPLACE_WORKING_TENDER_FACT_TYPE = "pos.working_tender_replaced"
  RETURN_TO_SALE_CLEAR_TENDERS_FACT_TYPE = "pos.working_tenders_cleared"
  ADD_WORKING_STORED_VALUE_TENDER_FACT_TYPE = "pos.working_stored_value_tender_added"
  ADD_WORKING_STORED_VALUE_REFUND_TENDER_FACT_TYPE = "pos.working_stored_value_refund_tender_added"
  ADD_WORKING_ISSUANCE_FACT_TYPE = "pos.working_issuance_added"
  REMOVE_WORKING_ISSUANCE_FACT_TYPE = "pos.working_issuance_removed"
  REPLACE_WORKING_ISSUANCE_FACT_TYPE = "pos.working_issuance_replaced"
  LEASE_DURATION = 2.minutes

  belongs_to :pos_transaction, optional: true
  belongs_to :store, optional: true
  belongs_to :register, optional: true

  validates :command_type, :source_id, :idempotency_key, :command_payload_hash, :status, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :idempotency_key, uniqueness: { scope: %i[source_id command_type] }

  def readonly?
    super || (persisted? && attribute_in_database("status") == "completed")
  end
end
