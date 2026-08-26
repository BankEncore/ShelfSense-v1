# frozen_string_literal: true

module Admin
  class StoredValueReportsController < BaseController
    before_action -> { require_permission!("stored_value.view_activity") }

    def show
      open_accounts = StoredValueAccount.where.not(status: "closed")
      @liability_rows = StoredValueAccount::ACCOUNT_TYPES.map do |type|
        scoped = open_accounts.where(account_type: type)
        [ type.humanize, scoped.count, scoped.sum(:balance_cents) ]
      end
      @cash_outs = GiftCardCashOut.originals.includes(:gift_card, :register, :pos_session).order(posted_at: :desc).limit(50)
    end
  end
end
