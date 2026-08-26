module AnnesAuth
  class Account < ApplicationRecord
    self.table_name = AnnesAuth.configuration.account_table_name

    has_secure_password

    has_many :account_sessions,
      class_name: AnnesAuth.configuration.account_session_class_name,
      foreign_key: AnnesAuth.configuration.account_foreign_key,
      dependent: :destroy,
      inverse_of: :account
    has_many :account_identities,
      class_name: AnnesAuth.configuration.account_identity_class_name,
      foreign_key: AnnesAuth.configuration.account_foreign_key,
      dependent: :destroy,
      inverse_of: :account
    has_many :account_verification_tokens,
      class_name: AnnesAuth.configuration.account_verification_token_class_name,
      foreign_key: AnnesAuth.configuration.account_foreign_key,
      dependent: :destroy,
      inverse_of: :account
    has_many :account_password_reset_tokens,
      class_name: AnnesAuth.configuration.account_password_reset_token_class_name,
      foreign_key: AnnesAuth.configuration.account_foreign_key,
      dependent: :destroy,
      inverse_of: :account
    has_many :account_invitation_tokens,
      class_name: AnnesAuth.configuration.account_invitation_token_class_name,
      foreign_key: AnnesAuth.configuration.account_foreign_key,
      dependent: :destroy,
      inverse_of: :account

    normalizes :email, with: ->(email) { email.strip.downcase }

    validates :email,
      presence: true,
      format: { with: ->(_account) { AnnesAuth.configuration.account_email_format } },
      uniqueness: { case_sensitive: false }
    validate :password_meets_minimum_length, if: -> { password.present? }

    scope :active, -> { where(disabled_at: nil) }

    def disabled?
      disabled_at.present?
    end

    def email_verified?
      email_verified_at.present?
    end

    def verify_email!
      update!(email_verified_at: Time.current)
    end

    private
      def password_meets_minimum_length
        minimum_length = AnnesAuth.configuration.account_password_minimum_length
        return if password.length >= minimum_length

        errors.add(:password, :too_short, count: minimum_length)
      end
  end
end
