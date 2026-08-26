module AnnesAuth
  module Accounts
    class EmailVerificationsController < AnnesAuth::ApplicationController
      layout "annes_auth"

      before_action :require_account_authentication, only: %i[pending verify resend create]
      rate_limit to: 3, within: 10.minutes, by: -> { email_verification_resend_rate_limit_key }, only: %i[resend create], with: -> { redirect_to auth_route(:account_email_verification_pending_path), alert: "時間をおいて再度お試しください。" }

      def pending
        redirect_authenticated_account(verified_notice: "メール認証は完了しています。") if current_account.email_verified?
      end

      def show
        redirect_to auth_route(:account_email_verification_pending_path), alert: "メールに記載された認証コードを入力してください。"
      end

      def verify
        code_lookup = verification_token_class.lookup_for(current_account, params[:otp])

        if code_lookup.success?
          account = verify_account(code_lookup.verification_token)
          AnnesAuth::AccountEvent.emit(
            :email_verified,
            account:,
            account_session: current_account_session,
            request:,
            auth_method: :email_verification
          )
          redirect_to after_account_email_verification_url(account), status: :see_other, notice: "メール認証が完了しました。"
        else
          redirect_to auth_route(:account_email_verification_pending_path),
            status: :see_other,
            alert: verification_error_message(code_lookup.status)
        end
      end

      def create
        resend
      end

      def resend
        _verification_token, plain_code = verification_token_class.issue_for(current_account)
        AnnesAuth.configuration.account_mailer_class.with(account: current_account, plain_code:).verification.deliver_now

        redirect_to auth_route(:account_email_verification_pending_path),
          status: :see_other,
          notice: "認証メールを再送しました。"
      end

      private
        def after_account_email_verification_url(account)
          AnnesAuth.configuration.after_account_email_verification_path.call(self, account)
        end

        def verification_token_class
          AnnesAuth.configuration.account_verification_token_class
        end

        def email_verification_resend_rate_limit_key
          "account:#{current_account&.id || request.remote_ip}"
        end

        def verify_account(verification_token)
          verification_token.verify!
          account = verification_token.account

          start_new_account_session_for(account) unless account_authenticated?

          account
        end

        def verification_error_message(status)
          case status
          when :expired
            "認証コードの有効期限が切れています。"
          when :used
            "認証コードが正しくありません。"
          when :too_many_attempts
            "認証コードの入力回数が上限に達しました。認証メールを再送してください。"
          else
            "認証コードが正しくありません。"
          end
        end
    end
  end
end
