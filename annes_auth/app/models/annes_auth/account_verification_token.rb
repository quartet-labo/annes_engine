require "openssl"

module AnnesAuth
  class AccountVerificationToken < ApplicationRecord
    self.table_name = AnnesAuth.configuration.account_verification_token_table_name

    CODE_DIGITS = 6
    CODE_FORMAT = /\A\d{6}\z/
    DEFAULT_TTL = 15.minutes
    MAX_ATTEMPTS = 5

    LookupResult = Data.define(:status, :verification_token) do
      def success?
        status == :ok
      end
    end

    belongs_to :account,
      class_name: AnnesAuth.configuration.account_class_name,
      foreign_key: AnnesAuth.configuration.account_foreign_key,
      inverse_of: :account_verification_tokens

    validates :token_digest, presence: true
    validates :expires_at, presence: true
    validates :attempt_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    scope :active, -> { where(used_at: nil).where("expires_at > ?", Time.current) }

    def self.issue_for(account, expires_at: DEFAULT_TTL.from_now)
      transaction do
        account.with_lock do
          account.account_verification_tokens.active.update_all(used_at: Time.current, updated_at: Time.current)
          code = generate_code
          verification_token = account.account_verification_tokens.create!(
            token_digest: digest_for(account, code),
            expires_at:,
            attempt_count: 0
          )

          [ verification_token, code ]
        end
      end
    end

    def self.lookup_for(account, code)
      normalized_code = normalize_code(code)
      return LookupResult.new(:invalid, nil) unless account && normalized_code.match?(CODE_FORMAT)

      verification_token = account.account_verification_tokens
        .where(token_digest: digest_for(account, normalized_code))
        .order(created_at: :desc, id: :desc)
        .first

      if verification_token
        return LookupResult.new(:used, verification_token) if verification_token.used?
        return LookupResult.new(:expired, verification_token) if verification_token.expired?
        return LookupResult.new(:too_many_attempts, verification_token) if verification_token.too_many_attempts?

        return LookupResult.new(:ok, verification_token)
      end

      record_failed_attempt_for(account)
      LookupResult.new(:invalid, nil)
    end

    def self.digest_for(account, code)
      digest_for_account_id(account.id, code)
    end

    def self.digest_for_account_id(account_id, code)
      OpenSSL::HMAC.hexdigest("SHA256", digest_secret, "#{account_id}:#{normalize_code(code)}")
    end

    def self.normalize_code(code)
      code.to_s.delete(" \t\r\n-")
    end

    def self.generate_code
      SecureRandom.random_number(10**CODE_DIGITS).to_s.rjust(CODE_DIGITS, "0")
    end

    def self.record_failed_attempt_for(account)
      account.account_verification_tokens.active
        .where(arel_table[:attempt_count].lt(MAX_ATTEMPTS))
        .order(created_at: :desc, id: :desc)
        .first&.record_failed_attempt!
    end

    def self.digest_secret
      Rails.application.key_generator.generate_key(AnnesAuth.configuration.account_verification_digest_salt, 32)
    end

    def verify!
      transaction do
        update!(used_at: Time.current)
        account.verify_email!
      end
    end

    def used?
      used_at.present?
    end

    def expired?
      expires_at.present? && expires_at <= Time.current
    end

    def too_many_attempts?
      attempt_count >= MAX_ATTEMPTS
    end

    def record_failed_attempt!
      with_lock do
        return if used? || expired? || too_many_attempts?

        update!(attempt_count: attempt_count + 1, last_attempted_at: Time.current)
      end
    end
  end
end
