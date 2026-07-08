module AnneAuth
  class Current < ActiveSupport::CurrentAttributes
    attribute :session, :account_session

    delegate :admin_user, to: :session, allow_nil: true
    delegate :account, to: :account_session, allow_nil: true
  end
end
