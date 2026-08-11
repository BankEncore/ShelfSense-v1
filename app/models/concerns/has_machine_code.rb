# frozen_string_literal: true

module HasMachineCode
  extend ActiveSupport::Concern

  included do
    before_validation :prepare_machine_code
    validate :code_immutable_after_create, on: :update
  end

  class_methods do
    def machine_code_optional?
      false
    end
  end

  private

  def prepare_machine_code
    if new_record?
      source = code.presence || name
      if source.blank?
        self.code = nil if self.class.machine_code_optional?
        return
      end

      normalized = Codes::Normalizer.normalize(source)
      if normalized.blank?
        errors.add(:code, "is blank after normalization")
        self.code = nil
        return
      end
      self.code = normalized
    elsif will_save_change_to_code?
      # Leave value for immutability validation; do not re-normalize from name.
    end
  end

  def code_immutable_after_create
    return unless will_save_change_to_code?

    errors.add(:code, "cannot be changed after creation")
  end
end
