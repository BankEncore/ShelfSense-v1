# frozen_string_literal: true

class UserSession < ApplicationRecord
  IDLE_TTL = 12.hours
  ABSOLUTE_TTL = 14.days

  belongs_to :user
  belongs_to :revoked_by, class_name: "User", optional: true

  validates :token_digest, :last_seen_at, :expires_at, presence: true
  validates :token_digest, uniqueness: true

  scope :active, lambda {
    where(revoked_at: nil).where("expires_at > ?", Time.current)
  }

  def self.digest(token)
    Digest::SHA256.hexdigest(token)
  end

  def self.issue!(user:, ip_address: nil, user_agent: nil)
    raise ArgumentError, "user is not authenticatable" unless user.authenticatable?

    raw_token = SecureRandom.urlsafe_base64(32)
    session = create!(
      user: user,
      token_digest: digest(raw_token),
      last_seen_at: Time.current,
      expires_at: ABSOLUTE_TTL.from_now,
      ip_address: ip_address,
      user_agent: user_agent
    )
    [ session, raw_token ]
  end

  def active?
    revoked_at.nil? && expires_at > Time.current && !idle_expired?
  end

  def idle_expired?
    last_seen_at < IDLE_TTL.ago
  end

  def touch_last_seen!
    update!(last_seen_at: Time.current)
  end

  def revoke!(by: nil)
    update!(revoked_at: Time.current, revoked_by: by)
  end
end
