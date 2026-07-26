module Customers
  class HistoryController < BaseController
    def index
      @ledger_entries = loyalty_member.loyalty_ledger_entries
        .includes(:loyalty_location)
        .order(occurred_at: :desc, id: :desc)
      @redemptions = loyalty_member.loyalty_redemptions
        .includes(:loyalty_reward)
        .order(created_at: :desc, id: :desc)
    end
  end
end
