module AnnesAuth
  class AccountIdentity < ApplicationRecord
    self.table_name = AnnesAuth.configuration.account_identity_table_name

    belongs_to :account,
      class_name: AnnesAuth.configuration.account_class_name,
      foreign_key: AnnesAuth.configuration.account_foreign_key,
      inverse_of: :account_identities

    normalizes :email, with: ->(email) { email.strip.downcase }
    normalizes :provider, with: ->(provider) { provider.strip.downcase }

    validates :provider, presence: true
    validates :uid, presence: true
    validates :provider, uniqueness: { scope: :uid }
    validates AnnesAuth.configuration.account_foreign_key, uniqueness: { scope: :provider }
    validates :email,
      format: { with: ->(_identity) { AnnesAuth.configuration.account_email_format } },
      allow_blank: true
  end
end
