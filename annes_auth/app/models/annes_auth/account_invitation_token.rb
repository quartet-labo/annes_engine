require "digest"

module AnnesAuth
  class AccountInvitationToken < ApplicationRecord
    self.table_name = AnnesAuth.configuration.account_invitation_token_table_name

    DEFAULT_TTL = 1.hour
    TOKEN_BYTES = 32
    TOKEN_FORMAT = /\A[A-Za-z0-9\-_]{20,}\z/

    class InvalidAccountError < StandardError; end

    LookupResult = Data.define(:status, :invitation_token) do
      def success?
        status == :ok
      end
    end

    belongs_to :account,
      class_name: AnnesAuth.configuration.account_class_name,
      foreign_key: AnnesAuth.configuration.account_foreign_key,
      inverse_of: :account_invitation_tokens

    validates :token_digest, presence: true, uniqueness: true
    validates :expires_at, presence: true

    scope :active, -> { where(used_at: nil).where("expires_at > ?", Time.current) }

    def self.issue_for(account, expires_at: DEFAULT_TTL.from_now)
      raise InvalidAccountError, "account is not eligible for invitation" unless eligible_account?(account)

      attempts = 0

      begin
        attempts += 1
        account.with_lock do
          raise InvalidAccountError, "account is not eligible for invitation" unless eligible_account?(account)

          expire_active_for(account)
          token = SecureRandom.urlsafe_base64(TOKEN_BYTES, false)
          invitation_token = account.account_invitation_tokens.create!(
            token_digest: digest(token),
            expires_at:
          )

          return [ invitation_token, token ]
        end
      rescue ActiveRecord::RecordNotUnique
        retry if attempts < 3

        raise
      end
    end

    def self.lookup(token)
      return LookupResult.new(:invalid, nil) unless token.to_s.match?(TOKEN_FORMAT)

      invitation_token = includes(:account).find_by(token_digest: digest(token))
      return LookupResult.new(:invalid, nil) unless invitation_token
      return LookupResult.new(:used, invitation_token) if invitation_token.used?
      return LookupResult.new(:expired, invitation_token) if invitation_token.expired?
      return LookupResult.new(:disabled_account, invitation_token) if invitation_token.account.disabled?
      return LookupResult.new(:verified_account, invitation_token) if invitation_token.account.email_verified?

      LookupResult.new(:ok, invitation_token)
    end

    def self.digest(token)
      Digest::SHA256.hexdigest(token.to_s)
    end

    def self.expire_active_for(account)
      account.account_invitation_tokens.active.update_all(used_at: Time.current, updated_at: Time.current)
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

    def self.eligible_account?(account)
      account&.persisted? && !account.disabled? && !account.email_verified?
    end
    private_class_method :eligible_account?
  end
end
