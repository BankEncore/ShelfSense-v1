# frozen_string_literal: true

class AuditEvent < ApplicationRecord
  OUTCOMES = %w[succeeded failed denied].freeze
  ACTOR_TYPES = %w[user system integration scheduled_job anonymous].freeze

  belongs_to :actor_user, class_name: "User", optional: true
  belongs_to :store, optional: true
  belongs_to :register, optional: true

  validates :occurred_at, :recorded_at, :actor_type, :actor_label, :action, :outcome, :correlation_id, presence: true
  validates :outcome, inclusion: { in: OUTCOMES }
  validates :actor_type, inclusion: { in: ACTOR_TYPES }

  before_validation :set_recorded_defaults, on: :create

  def readonly?
    !new_record?
  end

  private

  def set_recorded_defaults
    self.occurred_at ||= Time.current
    self.recorded_at ||= Time.current
    self.created_at ||= recorded_at
    self.correlation_id ||= SecureRandom.uuid_v7
    self.metadata ||= {}
  end
end
