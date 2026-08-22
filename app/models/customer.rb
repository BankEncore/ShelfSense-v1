# frozen_string_literal: true

class Customer < ApplicationRecord
  has_many :customer_requests, dependent: :restrict_with_exception

  validates :display_name, presence: true

  scope :active, -> { where(active: true) }
  scope :admin_ordered, -> { order(:display_name, :id) }

  def admin_label
    display_name
  end

  def self.options_for_select(records = active.admin_ordered)
    Array(records).map { |customer| [ customer.admin_label, customer.id ] }
  end

  def reactivation_blockers
    []
  end
end
