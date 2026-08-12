# frozen_string_literal: true

module Inventory
  class PostAdjustment
    class Error < StandardError; end

    POLICIES = %w[reject_below_zero].freeze

    def self.call(**attrs)
      new(**attrs).call
    end

    def self.preview(**attrs)
      new(**attrs).preview
    end

    def initialize(
      store:,
      product_variant:,
      adjustment_reason:,
      quantity_delta:,
      actor:,
      source_id:,
      idempotency_key:,
      notes: nil,
      acquisition_unit_cost_cents: nil,
      inventory_unit_id: nil,
      unit_identifier: nil,
      regular_price_cents: nil,
      occurred_at: nil,
      allow_backdate: false,
      negative_stock_policy: "reject_below_zero",
      correlation_id: nil
    )
      @store = store
      @product_variant = product_variant
      @adjustment_reason = adjustment_reason
      @quantity_delta = quantity_delta.to_i
      @actor = actor
      @source_id = source_id
      @idempotency_key = idempotency_key
      @notes = notes
      @acquisition_unit_cost_cents = acquisition_unit_cost_cents
      @inventory_unit_id = inventory_unit_id
      @unit_identifier = unit_identifier
      @regular_price_cents = regular_price_cents
      @occurred_at = occurred_at
      @allow_backdate = allow_backdate
      @negative_stock_policy = negative_stock_policy
      @correlation_id = correlation_id || SecureRandom.uuid_v7
    end

    def preview
      validate_request!
      effects = compute_effects(balance_snapshot)
      {
        tracking: tracking,
        quantity_delta: @quantity_delta,
        value_delta_cents: effects[:value_delta_cents],
        resulting_on_hand: effects[:resulting_on_hand],
        resulting_value_cents: effects[:resulting_value_cents],
        business_date: business_date,
        occurred_at: effective_occurred_at
      }
    end

    def call
      payload = command_payload
      op = Idempotency::OperationService.begin!(
        source_id: @source_id,
        operation_type: "post_inventory_adjustment",
        idempotency_key: @idempotency_key,
        payload: payload
      )
      if op.replayed
        return InventoryAdjustment.find(op.operation.result_id) if op.operation.result_id

        raise Error, "idempotent replay missing result"
      end

      InventoryAdjustment.transaction do
        validate_request!
        balance = lock_or_create_balance!
        effects = compute_effects(balance)
        apply_negative_stock_policy!(effects)

        unit = nil
        if tracking == "individual"
          unit = @quantity_delta.positive? ? create_unit!(effects) : remove_unit!(effects)
        end

        adjustment = InventoryAdjustment.create!(
          store: @store,
          product_variant: @product_variant,
          inventory_unit: unit,
          adjustment_reason: @adjustment_reason,
          quantity_delta: @quantity_delta,
          acquisition_unit_cost_cents: @quantity_delta.positive? ? @acquisition_unit_cost_cents : nil,
          notes: @notes,
          created_by: @actor,
          business_date: business_date,
          occurred_at: effective_occurred_at,
          posted_at: Time.current
        )

        ledger = InventoryLedgerEntry.create!(
          store: @store,
          product_variant: @product_variant,
          inventory_unit: unit,
          quantity_delta: @quantity_delta,
          entry_type: "adjustment",
          source_type: "InventoryAdjustment",
          source_id: adjustment.id,
          effect_sequence: 0,
          business_date: business_date,
          occurred_at: effective_occurred_at,
          actor_type: "User",
          actor_id: @actor.id
        )

        valuation = InventoryValuationEntry.create!(
          store: @store,
          product_variant: @product_variant,
          inventory_unit: unit,
          quantity_delta: @quantity_delta,
          value_delta_cents: effects[:value_delta_cents],
          acquisition_unit_cost_cents: @quantity_delta.positive? ? @acquisition_unit_cost_cents : nil,
          valuation_method: tracking == "individual" ? "specific_identification" : "moving_average",
          entry_type: @quantity_delta.positive? ? "acquisition" : "depletion",
          source_type: "InventoryAdjustment",
          source_id: adjustment.id,
          effect_sequence: 0,
          calculation_metadata: effects[:metadata],
          business_date: business_date,
          occurred_at: effective_occurred_at
        )

        balance.update!(
          on_hand_quantity: effects[:resulting_on_hand],
          inventory_value_cents: effects[:resulting_value_cents]
        )

        Audit::Recorder.record!(
          action: "inventory.adjustment_posted",
          outcome: "succeeded",
          actor_user: @actor,
          store: @store,
          subject: adjustment,
          correlation_id: @correlation_id,
          after_values: {
            quantity_delta: @quantity_delta,
            value_delta_cents: effects[:value_delta_cents],
            product_variant_id: @product_variant.id,
            inventory_unit_id: unit&.id
          },
          metadata: { idempotency_key: @idempotency_key, ledger_id: ledger.id, valuation_id: valuation.id }
        )

        Outbox::Recorder.record!(
          event_type: "inventory.adjustment_posted",
          aggregate: adjustment,
          correlation_id: @correlation_id,
          occurred_at: adjustment.posted_at,
          payload: {
            store_id: @store.id,
            product_variant_id: @product_variant.id,
            quantity_delta: @quantity_delta,
            value_delta_cents: effects[:value_delta_cents]
          }
        )

        Idempotency::OperationService.complete!(
          op.operation,
          result_type: "InventoryAdjustment",
          result_id: adjustment.id,
          result_payload: { id: adjustment.id }
        )

        adjustment
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      fail_operation!(op, e.message)
      raise Error, e.message
    rescue StandardError => e
      fail_operation!(op, e.message)
      raise
    end

    private

    def tracking
      @tracking ||= @product_variant.derived_inventory_tracking
    end

    def command_payload
      {
        store_id: @store.id,
        product_variant_id: @product_variant.id,
        adjustment_reason_id: @adjustment_reason.id,
        quantity_delta: @quantity_delta,
        acquisition_unit_cost_cents: @acquisition_unit_cost_cents,
        inventory_unit_id: @inventory_unit_id,
        unit_identifier: @unit_identifier,
        regular_price_cents: @regular_price_cents,
        notes: @notes,
        occurred_at: (@allow_backdate ? parsed_occurred_at&.iso8601(6) : nil),
        negative_stock_policy: @negative_stock_policy
      }
    end

    def validate_request!
      raise Error, "unsupported negative stock policy" unless POLICIES.include?(@negative_stock_policy)
      raise Error, "variant is not inventory-tracked" if tracking.blank? || tracking == "non_inventory"
      raise Error, "quantity_delta must be nonzero" if @quantity_delta.zero?
      raise Error, "adjustment reason is inactive" unless @adjustment_reason.active?

      if tracking == "quantity" && !@adjustment_reason.allows_quantity_tracking?
        raise Error, "reason does not allow quantity tracking"
      end
      if tracking == "individual" && !@adjustment_reason.allows_individual_tracking?
        raise Error, "reason does not allow individual tracking"
      end

      if @quantity_delta.positive?
        if @adjustment_reason.direction == "decrease"
          raise Error, "reason does not allow increases"
        end
        if @adjustment_reason.cost_required_for_increase && @acquisition_unit_cost_cents.nil?
          raise Error, "acquisition unit cost is required"
        end
        if @acquisition_unit_cost_cents.present? && @acquisition_unit_cost_cents.negative?
          raise Error, "acquisition unit cost must be nonnegative"
        end
      else
        raise Error, "reason does not allow decreases" if @adjustment_reason.direction == "increase"
      end

      raise Error, "notes are required" if @adjustment_reason.notes_required? && @notes.blank?

      if tracking == "individual"
        raise Error, "individual adjustments must change quantity by exactly one" unless @quantity_delta.abs == 1
        resolve_removal_unit! if @quantity_delta.negative?
      end

      validate_occurred_at!
    end

    def resolve_removal_unit!
      if @inventory_unit_id.blank? && @unit_identifier.present?
        normalized =
          begin
            Identifiers::Normalizer.normalize(@unit_identifier, allow_shelfsense_222: true)
          rescue Identifiers::NormalizationError => e
            raise Error, e.message
          end
        unit = InventoryUnit.find_by(unit_identifier: normalized)
        raise Error, "inventory unit not found for identifier #{normalized}" if unit.nil?

        @inventory_unit_id = unit.id
      end

      raise Error, "unit identifier is required for individual removals" if @inventory_unit_id.blank?
    end

    def fail_operation!(op, message)
      return unless defined?(op) && op && !op.replayed

      Idempotency::OperationService.fail!(op.operation, message: message)
    end

    def validate_occurred_at!
      at = effective_occurred_at
      raise Error, "effective time cannot be in the future" if at > Time.current + 1.second

      latest = InventoryLedgerEntry.where(store_id: @store.id, product_variant_id: @product_variant.id)
        .maximum(:occurred_at)
      return if latest.blank?
      return if at >= latest
      return if @allow_backdate

      raise Error, "effective time cannot be earlier than the latest inventory event for this store and variant"
    end

    def effective_occurred_at
      @effective_occurred_at ||= begin
        if @allow_backdate
          parsed_occurred_at || Time.current
        else
          Time.current
        end
      end
    end

    def parsed_occurred_at
      return if @occurred_at.blank?
      return @occurred_at if @occurred_at.acts_like?(:time)

      Time.zone.parse(@occurred_at.to_s) || (raise Error, "occurred_at is invalid")
    rescue ArgumentError
      raise Error, "occurred_at is invalid"
    end

    def business_date
      @business_date ||= BusinessDate.for_store(@store, at: effective_occurred_at)
    end

    def balance_snapshot
      InventoryBalance.find_by(store_id: @store.id, product_variant_id: @product_variant.id) ||
        InventoryBalance.new(store: @store, product_variant: @product_variant, on_hand_quantity: 0, inventory_value_cents: 0)
    end

    def lock_or_create_balance!
      balance = InventoryBalance.lock.find_by(store_id: @store.id, product_variant_id: @product_variant.id)
      return balance if balance

      begin
        InventoryBalance.transaction(requires_new: true) do
          InventoryBalance.create!(
            store: @store,
            product_variant: @product_variant,
            on_hand_quantity: 0,
            inventory_value_cents: 0
          )
        end
      rescue ActiveRecord::RecordNotUnique
        InventoryBalance.lock.find_by!(store_id: @store.id, product_variant_id: @product_variant.id)
      else
        InventoryBalance.lock.find_by!(store_id: @store.id, product_variant_id: @product_variant.id)
      end
    end

    def compute_effects(balance)
      qty = balance.on_hand_quantity
      value = balance.inventory_value_cents

      if tracking == "individual"
        if @quantity_delta.positive?
          cost = @acquisition_unit_cost_cents.to_i
          {
            value_delta_cents: cost,
            resulting_on_hand: qty + 1,
            resulting_value_cents: value + cost,
            metadata: { prior_quantity: qty, prior_value_cents: value }
          }
        else
          unit = InventoryUnit.lock.find(@inventory_unit_id)
          raise Error, "unit must be on hand" unless unit.on_hand?
          raise Error, "unit store mismatch" unless unit.store_id == @store.id
          raise Error, "unit variant mismatch" unless unit.product_variant_id == @product_variant.id

          relieved = unit.carrying_value_cents
          {
            value_delta_cents: -relieved,
            resulting_on_hand: qty - 1,
            resulting_value_cents: value - relieved,
            unit: unit,
            metadata: { prior_quantity: qty, prior_value_cents: value, unit_carrying_value_cents: relieved }
          }
        end
      elsif @quantity_delta.positive?
        incoming = @quantity_delta * @acquisition_unit_cost_cents.to_i
        {
          value_delta_cents: incoming,
          resulting_on_hand: qty + @quantity_delta,
          resulting_value_cents: value + incoming,
          metadata: { prior_quantity: qty, prior_value_cents: value }
        }
      else
        removal = -@quantity_delta
        raise Error, "insufficient on-hand quantity" if removal > qty

        removed_value =
          if qty <= 0
            0
          else
            Costing.value_removed_cents(
              current_value_cents: value,
              current_quantity: qty,
              removal_magnitude: [ removal, qty ].min
            )
          end
        # Final depletion when removing all remaining under reject policy, or exact clear
        if removal >= qty && qty.positive?
          removed_value = value
        end

        {
          value_delta_cents: -removed_value,
          resulting_on_hand: qty - removal,
          resulting_value_cents: value - removed_value,
          metadata: { prior_quantity: qty, prior_value_cents: value }
        }
      end
    end

    def apply_negative_stock_policy!(effects)
      return if effects[:resulting_on_hand] >= 0 && effects[:resulting_value_cents] >= 0

      raise Error, "posting would reduce on-hand or value below zero"
    end

    def create_unit!(effects)
      attempts = 0
      begin
        attempts += 1
        identifier = @unit_identifier.presence || Identifiers::Generator.next_ean13!("220")
        price = @regular_price_cents
        price = @product_variant.regular_price_cents if price.nil?

        unit = InventoryUnit.create!(
          product_variant: @product_variant,
          store: @store,
          unit_identifier: identifier,
          lifecycle_state: "on_hand",
          acquisition_cost_cents: @acquisition_unit_cost_cents,
          carrying_value_cents: @acquisition_unit_cost_cents,
          regular_price_cents: price
        )
        Identifiers::Registry.reserve!(value: identifier, kind: "inventory_unit", inventory_unit: unit)
        unit
      rescue Identifiers::Registry::ConflictError, ActiveRecord::RecordNotUnique
        raise Error, "unit identifier is already reserved" if @unit_identifier.present?
        retry if attempts < 5
        raise Error, "unable to allocate unit identifier"
      end
    end

    def remove_unit!(_effects)
      unit = InventoryUnit.lock.find(@inventory_unit_id)
      raise Error, "unit must be on hand" unless unit.on_hand?
      raise Error, "unit store mismatch" unless unit.store_id == @store.id
      raise Error, "unit variant mismatch" unless unit.product_variant_id == @product_variant.id

      unit.update!(lifecycle_state: "removed", removed_at: Time.current)
      unit
    end
  end
end
