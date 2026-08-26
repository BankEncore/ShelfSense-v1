# frozen_string_literal: true

class GiftCardProgram < ApplicationRecord
  AUTHORITIES = %w[system_generated manual_external].freeze
  CASH_OUT_POLICIES = %w[prohibited permitted_when_eligible required_on_request_when_eligible].freeze
  PHASE10_NUMBER_LENGTH = 20
  MERCHANDISE_SCAN_LENGTHS = [ 12, 13 ].freeze

  has_many :gift_cards, dependent: :restrict_with_exception

  validates :code, :name, :number_authority, :prefix, :check_digit_algorithm, :cash_out_policy, presence: true
  validates :code, uniqueness: { case_sensitive: false }
  validates :prefix, uniqueness: true, format: { with: /\A\d+\z/, message: "must be numeric" }
  validates :number_authority, inclusion: { in: AUTHORITIES }
  validates :cash_out_policy, inclusion: { in: CASH_OUT_POLICIES }
  validates :check_digit_algorithm, inclusion: { in: %w[luhn] }
  validates :number_length, inclusion: { in: [ PHASE10_NUMBER_LENGTH ] }
  validates :minimum_activation_cents, :maximum_balance_cents, :cash_out_threshold_cents,
            numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :prefix_does_not_collide_with_merchandise
  validate :identity_immutable_after_activation, on: :update
  validate :code_immutable, on: :update
  before_validation :normalize_identity

  scope :active, -> { where(active: true) }
  scope :admin_ordered, -> { order(:code) }

  def system_generated?
    number_authority == "system_generated"
  end

  def manual_external?
    number_authority == "manual_external"
  end

  def activation_exists?
    gift_cards.exists?
  end

  def masked_example
    "#{prefix}#{'•' * (number_length - prefix.length - 4)}####"
  end

  private

  def normalize_identity
    self.code = code.to_s.strip.downcase
    self.prefix = prefix.to_s.strip
  end

  def prefix_does_not_collide_with_merchandise
    return if prefix.blank? || number_length.blank?
    return unless MERCHANDISE_SCAN_LENGTHS.include?(number_length)

    errors.add(:number_length, "collides with merchandise identifier namespaces")
  end

  def identity_immutable_after_activation
    return unless activation_exists?

    %i[prefix number_length number_authority check_digit_algorithm].each do |attr|
      errors.add(attr, "cannot change after a card has been activated") if will_save_change_to_attribute?(attr)
    end
  end

  def code_immutable
    errors.add(:code, "cannot change after create") if will_save_change_to_code?
  end
end
