module AnnesAuth
  class BootstrapClaim < ApplicationRecord
    self.table_name = AnnesAuth.configuration.bootstrap_claim_table_name

    INITIAL_ACCOUNT_PURPOSE = "initial_account".freeze

    validates :purpose, presence: true, uniqueness: true
  end
end
