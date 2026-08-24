# frozen_string_literal: true

class BibliographicLookupCache < ApplicationRecord
  self.table_name = "bibliographic_lookup_cache"

  validates :lookup_key, :provider, :payload, :fetched_at, :expires_at, presence: true
  validates :lookup_key, uniqueness: true

  scope :fresh, -> { where("expires_at > ?", Time.current) }

  def expired?
    expires_at <= Time.current
  end
end
