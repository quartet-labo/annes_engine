module AnnesAuth
  module Accounts
    class InvitationDelivery
      Result = Data.define(:status) do
        def success?
          status == :delivered
        end
      end

      def self.call(account)
        new(account).call
      end

      def initialize(account)
        @account = account
      end

      def call
        return Result.new(:invalid_account) unless eligible_account?

        _invitation_token, plain_token = issue_invitation
        deliver_invitation(plain_token)
      rescue AnnesAuth::AccountInvitationToken::InvalidAccountError
        Result.new(:invalid_account)
      end

      private
        attr_reader :account

        def eligible_account?
          account&.persisted? && !account.disabled? && !account.email_verified?
        end

        def issue_invitation
          AnnesAuth.configuration.account_invitation_token_class.issue_for(account)
        end

        def deliver_invitation(plain_token)
          result = deliver_invitation_mail(plain_token)
          return result unless result.success?

          AnnesAuth::AccountEvent.emit(
            :invitation_sent,
            account:,
            auth_method: :invitation
          )

          result
        end

        def deliver_invitation_mail(plain_token)
          AnnesAuth.configuration.account_mailer_class
            .with(account:, plain_token:)
            .invitation
            .deliver_now

          Result.new(:delivered)
        rescue StandardError => error
          Rails.logger.error("AnnesAuth invitation delivery failed (#{error.class.name})")
          Result.new(:delivery_failed)
        end
    end
  end
end
