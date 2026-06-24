module AnneAuth
  class AccountIdentity < ApplicationRecord
    self.table_name = AnneAuth.configuration.account_identity_table_name

    belongs_to :account,
      class_name: AnneAuth.configuration.account_class_name,
      foreign_key: AnneAuth.configuration.account_foreign_key,
      inverse_of: :account_identities

    normalizes :email, with: ->(email) { email.strip.downcase }
    normalizes :provider, with: ->(provider) { provider.strip.downcase }

    validates :provider, presence: true
    validates :uid, presence: true
    validates :provider, uniqueness: { scope: :uid }
    validates AnneAuth.configuration.account_foreign_key, uniqueness: { scope: :provider }
    validates :email,
      format: { with: ->(_identity) { AnneAuth.configuration.account_email_format } },
      allow_blank: true
  end
end
