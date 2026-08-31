# frozen_string_literal: true

module Pos
  module Support
    module_function

    def authorize!(actor, store)
      unless Authorization::PermissionEvaluator.allowed?(user: actor, permission_key: "pos.transact", store: store)
        raise Pos::Denied, "not authorized to transact at this store"
      end
    end

    def require_active_context!(store, register)
      raise Pos::Error, "store is not active" unless Store.where(id: store.id, active: true).exists?
      raise Pos::Error, "register is not active" unless Register.where(id: register.id, active: true).exists?
    end

    def require_session_cashier!(actor, session)
      raise Pos::Denied, "actor is not the session cashier" unless actor.id == session.cashier_user_id
    end

    def require_transaction_cashier!(actor, transaction)
      session = transaction.pos_session
      unless actor.id == transaction.cashier_user_id && transaction.cashier_user_id == session.cashier_user_id
        raise Pos::Denied, "actor is not the transaction cashier"
      end
    end

    # Assumes the Session is already locked and validated. Not a public bypass of
    # StartTransaction or ResumeOrStartTransaction.
    def create_working_transaction!(session:, currency_code:)
      PosTransaction.create!(
        store: session.store,
        register: session.register,
        pos_session: session,
        reporting_period: session.reporting_period,
        cashier_user: session.cashier_user,
        status: "working",
        currency_code: currency_code
      )
    end

    def lock_open_cashier_session!(session, actor)
      locked = PosSession.lock.find(session.id)
      authorize!(actor, locked.store)
      require_active_context!(locked.store, locked.register)
      require_session_cashier!(actor, locked)
      raise Pos::Error, "session is not open" unless locked.open?
      raise Pos::Error, "reporting period is not open" unless locked.reporting_period.open?

      locked
    end

    def clear_working_tenders!(transaction)
      tenders = transaction.pos_tenders
      return false if tenders.empty?

      tenders.destroy_all
      true
    end

    def cash_tender_type
      TenderType.find_by!(code: "cash")
    end

    def applied_payment_cents(transaction, except: nil)
      scope = transaction.pos_tenders.payments
      scope = scope.where.not(id: except.id) if except
      scope.sum(:amount_cents)
    end

    def applied_refund_cents(transaction, except: nil)
      scope = transaction.pos_tenders.refunds
      scope = scope.where.not(id: except.id) if except
      scope.sum(:amount_cents)
    end

    def remaining_due_cents(transaction, except: nil)
      transaction.total_cents - applied_payment_cents(transaction, except: except)
    end

    def settlement_direction(transaction)
      net = transaction.signed_net_cents
      return :payment if net.positive?
      return :refund if net.negative?

      :none
    end

    def remaining_payment_cents(transaction, except: nil)
      return 0 unless transaction.signed_net_cents.positive?

      [ transaction.signed_net_cents - applied_payment_cents(transaction, except: except), 0 ].max
    end

    def remaining_refund_cents(transaction, except: nil)
      return 0 unless transaction.signed_net_cents.negative?

      [ -transaction.signed_net_cents - applied_refund_cents(transaction, except: except), 0 ].max
    end

    def exact_settlement?(transaction)
      tenders = transaction.pos_tenders.to_a
      case settlement_direction(transaction)
      when :none
        commercial_content?(transaction) && tenders.empty?
      when :payment
        tenders.any? &&
          tenders.all? { |tender| tender.direction == "payment" } &&
          applied_payment_cents(transaction) == transaction.signed_net_cents
      when :refund
        tenders.any? &&
          tenders.all? { |tender| tender.direction == "refund" } &&
          applied_refund_cents(transaction) == -transaction.signed_net_cents
      end
    end

    def snapshot_tender_identity!(tender, type)
      tender.configured_tender_type = type
      tender.tender_type = type.code
      tender.tender_name = type.name
      tender.behavioral_category = type.behavioral_category
    end

    def next_tender_number(transaction)
      (transaction.pos_tenders.maximum(:tender_number) || 0) + 1
    end

    def renumber_tenders!(transaction)
      tenders = transaction.pos_tenders.ordered.to_a
      return if tenders.empty?

      tenders.each_with_index do |tender, index|
        tender.update_columns(tender_number: index + 1_000)
      end
      tenders.each_with_index do |tender, index|
        tender.update_columns(tender_number: index + 1)
      end
    end

    def touch_working_transaction!(transaction)
      transaction.update!(updated_at: Time.current)
    end

    def parse_nonnegative_cents!(value, label)
      cents = Integer(value)
      raise Pos::Error, "#{label} must be a non-negative integer" if cents.negative?

      cents
    rescue ArgumentError, TypeError
      raise Pos::Error, "#{label} must be a non-negative integer"
    end

    def lock_working_transaction!(transaction, expected_lock_version)
      transaction.lock!
      raise Pos::Error, "transaction is not working" unless transaction.working?
      if transaction.lock_version != expected_lock_version.to_i
        raise Pos::StaleObject, "stale lock_version"
      end

      transaction
    end

    def apply_provisional_tax!(line)
      line.recalc_extended! if line.net_merchandise_amount_cents.nil?
      result = Pos::Tax::Calculate.call(
        store: line.pos_transaction.store,
        tax_class: line.tax_class,
        taxable_basis_cents: line.net_merchandise_amount_cents
      )
      line.line_tax_cents = result.tax_cents
      line.line_total_cents = line.net_merchandise_amount_cents + line.line_tax_cents
      line.save!
      replace_line_tax_components!(line, result)
      result
    end

    def replace_line_tax_components!(line, result)
      line.pos_line_tax_components.delete_all
      result.determinations.each do |determination|
        line.pos_line_tax_components.create!(
          store_tax_id: determination.store_tax_id,
          store_tax_code_snapshot: determination.store_tax_code,
          store_tax_name_snapshot: determination.store_tax_name,
          rate_percent: determination.rate_percent,
          applies: determination.applies,
          taxable_basis_cents: determination.taxable_basis_cents,
          tax_cents: determination.tax_cents,
          calculation_order: determination.calculation_order
        )
      end
    end

    def commercial_content?(transaction)
      transaction.pos_transaction_lines.any? || transaction.pos_stored_value_issuances.any?
    end

    def require_commercial_content!(transaction)
      return if commercial_content?(transaction)

      raise Pos::Error, "transaction has no merchandise"
    end

    def nested_stored_value_idempotency_key(operation_id, kind, record_id)
      Digest::UUID.uuid_v5(operation_id.to_s, "#{kind}:#{record_id}")
    end

    def next_issuance_number(transaction)
      (transaction.pos_stored_value_issuances.maximum(:issuance_number) || 0) + 1
    end

    def issuance_contribution_cents(transaction)
      transaction.pos_stored_value_issuances.sum { |issuance|
        issuance.post_void_generated? ? -issuance.amount_cents : issuance.amount_cents
      }
    end

    def refresh_totals!(transaction)
      lines = transaction.pos_transaction_lines.reload
      sale_lines = lines.select(&:sale?)
      return_lines = lines.select(&:return?)

      transaction.subtotal_cents = sale_lines.sum(&:extended_selling_amount_cents)
      transaction.discount_cents = sale_lines.sum(&:manual_discount_cents)
      transaction.tax_cents = sale_lines.sum(&:line_tax_cents)
      sale_total = transaction.subtotal_cents - transaction.discount_cents + transaction.tax_cents

      transaction.return_subtotal_cents = return_lines.sum(&:extended_selling_amount_cents)
      transaction.return_discount_cents = return_lines.sum(&:manual_discount_cents)
      transaction.return_tax_cents = return_lines.sum(&:line_tax_cents)
      transaction.return_total_cents =
        transaction.return_subtotal_cents - transaction.return_discount_cents + transaction.return_tax_cents

      transaction.pos_stored_value_issuances.reload
      transaction.stored_value_issuance_cents = issuance_contribution_cents(transaction)
      transaction.signed_net_cents = sale_total + transaction.stored_value_issuance_cents - transaction.return_total_cents
      transaction.total_cents = transaction.signed_net_cents.abs
      transaction.save!
    end
  end
end
