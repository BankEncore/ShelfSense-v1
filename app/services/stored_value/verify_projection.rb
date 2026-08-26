# frozen_string_literal: true

module StoredValue
  class VerifyProjection
    Drift = Data.define(:account, :projected_cents, :ledger_cents)

    def self.call
      new.call
    end

    def call
      ledger_sums = StoredValueEntry.group(:stored_value_account_id).sum(:amount_cents)
      StoredValueAccount.order(:id).filter_map do |account|
        ledger_cents = ledger_sums.fetch(account.id, 0)
        next if account.balance_cents == ledger_cents

        Drift.new(account: account, projected_cents: account.balance_cents, ledger_cents: ledger_cents)
      end
    end
  end
end
