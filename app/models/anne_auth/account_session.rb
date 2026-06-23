module AnneAuth
  class AccountSession < ApplicationRecord
    self.table_name = AnneAuth.configuration.account_session_table_name

    belongs_to :account,
      class_name: AnneAuth.configuration.account_class_name,
      foreign_key: AnneAuth.configuration.account_foreign_key,
      inverse_of: :account_sessions
  end
end
