# frozen_string_literal: true

class Customer < ApplicationRecord
  PREFERRED_CONTACT_METHODS = %w[phone email none].freeze

  attribute :preferred_contact_method, :string, default: "none"

  belongs_to :merged_into_customer, class_name: "Customer", optional: true
  has_many :merged_aliases,
           class_name: "Customer",
           foreign_key: :merged_into_customer_id,
           inverse_of: :merged_into_customer,
           dependent: :restrict_with_exception
  has_many :customer_requests, dependent: :restrict_with_exception
  has_many :stored_value_accounts, dependent: :restrict_with_exception

  validates :display_name, presence: true
  validates :preferred_contact_method, inclusion: { in: PREFERRED_CONTACT_METHODS }
  validate :preferred_contact_method_has_value

  before_validation :derive_display_name_from_parts, :normalize_contact_fields

  scope :active, -> { where(active: true) }
  scope :canonical, -> { where(merged_into_customer_id: nil) }
  scope :merged, -> { where.not(merged_into_customer_id: nil) }
  scope :admin_ordered, -> { order(:display_name, :id) }

  def admin_label
    display_name
  end

  def self.options_for_select(records = active.canonical.admin_ordered)
    Array(records).map { |customer| [ customer.admin_label, customer.id ] }
  end

  # "Family, Given" when both present; otherwise the single non-blank part.
  def self.derived_display_name(family_name:, given_name:)
    family = family_name.to_s.strip.presence
    given = given_name.to_s.strip.presence
    return "#{family}, #{given}" if family && given
    return family if family
    given
  end

  def merged?
    merged_into_customer_id.present?
  end

  def canonical?
    merged_into_customer_id.blank?
  end

  def canonical
    return self if canonical?

    survivor = merged_into_customer
    raise "customer merge chain detected for #{id}" if survivor&.merged?

    survivor
  end

  def reactivation_blockers
    return [ "Customer was merged into another customer and cannot be reactivated." ] if merged?

    []
  end

  private

  def derive_display_name_from_parts
    return if display_name.to_s.strip.present?

    self.display_name = self.class.derived_display_name(
      family_name: family_name,
      given_name: given_name
    )
  end

  def normalize_contact_fields
    Customers::NormalizeContact.apply!(self)
  end

  def preferred_contact_method_has_value
    case preferred_contact_method
    when "phone"
      errors.add(:preferred_contact_method, "requires a phone number") if phone.blank?
    when "email"
      errors.add(:preferred_contact_method, "requires an email address") if email.blank?
    end
  end
end
