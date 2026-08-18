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
      result = Pos::Tax::Calculate.call(
        store: line.pos_transaction.store,
        tax_class: line.tax_class,
        taxable_basis_cents: line.extended_selling_amount_cents
      )
      line.line_tax_cents = result.tax_cents
      line.line_total_cents = line.extended_selling_amount_cents + line.line_tax_cents
    end

    def refresh_totals!(transaction)
      lines = transaction.pos_transaction_lines.reload
      transaction.subtotal_cents = lines.sum(&:extended_selling_amount_cents)
      transaction.tax_cents = lines.sum(&:line_tax_cents)
      transaction.total_cents = lines.sum(&:line_total_cents)
      transaction.save!
    end
  end
end
