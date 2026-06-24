require "digest"

module AnneAuth
  class AccountPasswordResetToken < ApplicationRecord
    self.table_name = AnneAuth.configuration.account_password_reset_token_table_name

    DEFAULT_TTL = 1.hour
    TOKEN_BYTES = 32
    TOKEN_FORMAT = /\A[A-Za-z0-9\-_]{20,}\z/

    LookupResult = Data.define(:status, :password_reset_token) do
      def success?
        status == :ok
      end
    end

    belongs_to :account,
      class_name: AnneAuth.configuration.account_class_name,
      foreign_key: AnneAuth.configuration.account_foreign_key,
      inverse_of: :account_password_reset_tokens

    validates :token_digest, presence: true, uniqueness: true
    validates :expires_at, presence: true

    scope :active, -> { where(used_at: nil).where("expires_at > ?", Time.current) }

    def self.issue_for(account, expires_at: DEFAULT_TTL.from_now)
      attempts = 0

      begin
        attempts += 1
        token = SecureRandom.urlsafe_base64(TOKEN_BYTES, false)
        password_reset_token = account.account_password_reset_tokens.create!(
          token_digest: digest(token),
          expires_at:
        )

        return [ password_reset_token, token ]
      rescue ActiveRecord::RecordNotUnique
        retry if attempts < 3

        raise
      end
    end

    def self.lookup(token)
      return LookupResult.new(:invalid, nil) unless token.to_s.match?(TOKEN_FORMAT)

      password_reset_token = find_by(token_digest: digest(token))
      return LookupResult.new(:invalid, nil) unless password_reset_token
      return LookupResult.new(:used, password_reset_token) if password_reset_token.used?
      return LookupResult.new(:expired, password_reset_token) if password_reset_token.expired?

      LookupResult.new(:ok, password_reset_token)
    end

    def self.digest(token)
      Digest::SHA256.hexdigest(token.to_s)
    end

    def mark_used!
      update!(used_at: Time.current)
    end

    def used?
      used_at.present?
    end

    def expired?
      expires_at.present? && expires_at <= Time.current
    end
  end
end
