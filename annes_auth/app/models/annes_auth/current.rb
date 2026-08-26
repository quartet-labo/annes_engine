module AnnesAuth
  class Current < ActiveSupport::CurrentAttributes
    attribute :account_session

    delegate :account, to: :account_session, allow_nil: true
  end
end
