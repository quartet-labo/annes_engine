module AnneAuth
  module Accounts
    class InvitationAcceptance
      Result = Data.define(:status, :account) do
        def success?
          status == :ok
        end
      end

      def self.call(invitation_token:, password:, password_confirmation:)
        new(invitation_token:, password:, password_confirmation:).call
      end

      def initialize(invitation_token:, password:, password_confirmation:)
        @invitation_token = invitation_token
        @password = password
        @password_confirmation = password_confirmation
      end

      def call
        return invalid_result unless invitation_token&.persisted?

        account = invitation_token.account
        return invalid_result unless account&.persisted?

        account.with_lock do
          locked_invitation = account.account_invitation_tokens.lock.find_by(id: invitation_token.id)
          return invalid_result unless acceptable?(locked_invitation, account)

          account.assign_attributes(password:, password_confirmation:)
          account.errors.add(:password, :blank) if password.blank?
          return Result.new(:invalid_password, account) unless account.errors.none? && account.valid?

          now = Time.current
          account.email_verified_at = now
          account.save!
          invalidate_credentials!(account, now:)

          Result.new(:ok, account)
        end
      end

      private
        attr_reader :invitation_token, :password, :password_confirmation

        def acceptable?(locked_invitation, account)
          locked_invitation.present? &&
            !locked_invitation.used? &&
            !locked_invitation.expired? &&
            !account.disabled? &&
            !account.email_verified?
        end

        def invalidate_credentials!(account, now:)
          mark_unused_tokens_used(account.account_invitation_tokens, now:)
          mark_unused_tokens_used(account.account_password_reset_tokens, now:)
          mark_unused_tokens_used(account.account_verification_tokens, now:)
          account.account_sessions.destroy_all
        end

        def mark_unused_tokens_used(tokens, now:)
          tokens.where(used_at: nil).update_all(used_at: now, updated_at: now)
        end

        def invalid_result
          Result.new(:invalid, nil)
        end
    end
  end
end
