# frozen_string_literal: true

module Audit
  class Recorder
    def self.record!(**attrs)
      new.record!(**attrs)
    end

    def record!(
      action:,
      outcome:,
      actor_user: nil,
      actor_type: nil,
      actor_label: nil,
      store: nil,
      workstation: nil,
      user_session_id: nil,
      subject: nil,
      subject_type: nil,
      subject_id: nil,
      subject_label: nil,
      reason_code: nil,
      reason_text: nil,
      correlation_id: nil,
      before_values: nil,
      after_values: nil,
      metadata: {},
      ip_address: nil,
      user_agent: nil,
      occurred_at: Time.current
    )
      AuditEvent.create!(
        action: action,
        outcome: outcome,
        actor_user: actor_user,
        actor_type: actor_type || (actor_user&.system_actor? ? "system" : "user"),
        actor_label: actor_label || actor_user&.display_name || "unknown",
        store: store,
        workstation: workstation,
        user_session_id: user_session_id,
        subject_type: subject_type || subject&.class&.name,
        subject_id: subject_id || subject&.id,
        subject_label: subject_label || subject_label_for(subject),
        reason_code: reason_code,
        reason_text: reason_text,
        correlation_id: correlation_id || SecureRandom.uuid_v7,
        before_values: before_values,
        after_values: after_values,
        metadata: metadata || {},
        ip_address: ip_address,
        user_agent: user_agent,
        occurred_at: occurred_at,
        application_version: Rails.application.config.x.application_version
      )
    end

    private

    def subject_label_for(subject)
      return if subject.nil?
      return subject.display_name if subject.respond_to?(:display_name)
      return subject.name if subject.respond_to?(:name)
      return subject.key if subject.respond_to?(:key)

      subject.to_s
    end
  end
end
