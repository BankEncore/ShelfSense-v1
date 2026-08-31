# frozen_string_literal: true

module Customers
  # Presentation-neutral customer identity creation for admin and Register Quick Customer.
  class Create
    Result = Data.define(:customer, :replayed, :operation)

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      display_name:,
      actor:,
      idempotency_key:,
      source_id:,
      email: nil,
      phone: nil,
      preferred_contact_method: nil,
      given_name: nil,
      family_name: nil,
      store: nil,
      acknowledge_duplicates: false,
      require_contact: false,
      correlation_id: nil
    )
      @display_name = display_name
      @given_name = given_name
      @family_name = family_name
      @email = email
      @phone = phone
      @preferred_contact_method = preferred_contact_method
      @actor = actor
      @idempotency_key = idempotency_key
      @source_id = source_id
      @store = store
      @acknowledge_duplicates = acknowledge_duplicates
      @require_contact = require_contact
      @correlation_id = correlation_id || SecureRandom.uuid_v7
    end

    def call
      raise Customers::Error, "actor is required" if @actor.blank?
      raise Customers::Error, "idempotency key is required" if @idempotency_key.blank?
      raise Customers::Error, "source id is required" if @source_id.blank?

      resolved_display_name = resolved_display_name!
      validate_contact_requirement!

      payload = command_payload(resolved_display_name)
      op = Idempotency::OperationService.begin!(
        source_id: @source_id,
        operation_type: "customers.create",
        idempotency_key: @idempotency_key,
        payload: payload
      )

      if op.replayed
        customer = Customer.find(op.operation.result_id)
        return Result.new(customer: customer, replayed: true, operation: op.operation)
      end

      begin
        result = nil
        Customer.transaction do
          unless @acknowledge_duplicates
            suggestions = Customers::SuggestDuplicates.call(
              attributes: suggestion_attributes(resolved_display_name)
            )
            raise Customers::DuplicateFoundError, suggestions if suggestions.any?
          end

          customer = Customer.new(
            display_name: resolved_display_name,
            given_name: @given_name,
            family_name: @family_name,
            email: @email,
            phone: @phone,
            preferred_contact_method: @preferred_contact_method.presence || "none"
          )
          Customers::NormalizeContact.apply!(customer)
          customer.save!

          Audit::Recorder.record!(
            action: "customers.create",
            outcome: "succeeded",
            actor_user: @actor,
            store: @store,
            subject: customer,
            correlation_id: @correlation_id,
            after_values: {
              display_name: customer.display_name,
              email: customer.email,
              phone: customer.phone,
              preferred_contact_method: customer.preferred_contact_method
            }
          )

          Idempotency::OperationService.complete!(
            op.operation,
            result_type: "Customer",
            result_id: customer.id,
            result_payload: {}
          )

          result = Result.new(customer: customer, replayed: false, operation: op.operation)
        end
        result
      rescue Customers::DuplicateFoundError
        Idempotency::OperationService.fail!(op.operation, message: "duplicate customers found")
        raise
      rescue Customers::Error, ActiveRecord::RecordInvalid => e
        Idempotency::OperationService.fail!(op.operation, message: e.message)
        raise Customers::Error, e.message
      rescue Idempotency::OperationService::PayloadMismatchError
        raise
      end
    end

    private

    def resolved_display_name!
      explicit = @display_name.to_s.strip.presence
      explicit ||= Customer.derived_display_name(
        family_name: @family_name,
        given_name: @given_name
      )
      raise Customers::Error, "display name is required" if explicit.blank?

      explicit
    end

    def validate_contact_requirement!
      return unless @require_contact

      email = @email.to_s.strip
      phone = @phone.to_s.strip
      return if email.present? || phone.present?

      raise Customers::Error, "email or phone is required for this flow"
    end

    def suggestion_attributes(display_name)
      {
        display_name: display_name,
        given_name: @given_name,
        family_name: @family_name,
        email: @email,
        phone: @phone
      }
    end

    # Acknowledgment is a deliberate UX step after a failed duplicate probe, not part of
    # the customer identity. Including it in the hash made "Create anyway" reuse a key
    # with a different payload and raise PayloadMismatchError.
    def command_payload(display_name)
      {
        display_name: display_name,
        given_name: @given_name.to_s.strip.presence,
        family_name: @family_name.to_s.strip.presence,
        email: Customers::NormalizeContact.email(@email),
        phone: Customers::NormalizeContact.phone(@phone),
        preferred_contact_method: @preferred_contact_method.to_s.strip.presence || "none",
        require_contact: @require_contact
      }
    end
  end
end
