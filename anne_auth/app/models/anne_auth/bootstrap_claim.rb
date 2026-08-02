module AnneAuth
  class BootstrapClaim < ApplicationRecord
    self.table_name = AnneAuth.configuration.bootstrap_claim_table_name

    INITIAL_ACCOUNT_PURPOSE = "initial_account".freeze

    validates :purpose, presence: true, uniqueness: true
  end
end
