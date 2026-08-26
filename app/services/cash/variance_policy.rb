# frozen_string_literal: true

module Cash
  class VariancePolicy
    Result = Struct.new(:reason, :approved_by, :notes, keyword_init: true)

    def self.for!(
      store:,
      actor:,
      variance_cents:,
      reason_code:,
      notes:,
      approver_username: nil,
      approver_password: nil
    )
      notes = notes.to_s.strip.presence
      return Result.new(reason: nil, approved_by: nil, notes: notes) if variance_cents.zero?

      kind = variance_cents.positive? ? "over" : "short"
      reason = ActivityReasons.require!(reason_code, kind)
      raise Error, "variance notes are required" if reason.notes_required && notes.blank?

      abs_variance = variance_cents.abs
      raise Error, "a note is required for this variance" if abs_variance >= Thresholds.note_cents(store) && notes.blank?

      approved_by = nil
      if abs_variance >= Thresholds.approval_cents(store)
        unless Authorization::PermissionEvaluator.allowed?(
          user: actor, permission_key: "cash.approve_variance", store: store
        )
          approved_by = Pos::AuthenticateApprover.call(
            username: approver_username,
            password: approver_password,
            store: store,
            action_type: "cash_variance",
            performer: actor,
            permission_key: "cash.approve_variance"
          )
        end
      end

      Result.new(reason: reason, approved_by: approved_by, notes: notes)
    end
  end
end
