module AnneAuth
  module Accounts
    class EmailVerificationsController < AnneAuth::ApplicationController
      layout "anne_auth"

      before_action :require_account_authentication, only: %i[pending verify resend create]

      def pending
        redirect_to auth_route(:root_path), notice: "メール認証は完了しています。" if current_account.email_verified?
      end

      def show
        redirect_to auth_route(:account_email_verification_pending_path), alert: "メールに記載された認証コードを入力してください。"
      end

      def verify
        code_lookup = verification_token_class.lookup_for(current_account, params[:otp])

        if code_lookup.success?
          verify_account(code_lookup.verification_token)
          redirect_to auth_route(:root_path), notice: "メール認証が完了しました。"
        else
          redirect_to auth_route(:account_email_verification_pending_path), alert: verification_error_message(code_lookup.status)
        end
      end

      def create
        resend
      end

      def resend
        _verification_token, plain_code = verification_token_class.issue_for(current_account)
        AnneAuth.configuration.account_mailer_class.with(account: current_account, plain_code:).verification.deliver_now

        redirect_to auth_route(:account_email_verification_pending_path), notice: "認証メールを再送しました。"
      end

      private
        def verification_token_class
          AnneAuth.configuration.account_verification_token_class
        end

        def verify_account(verification_token)
          verification_token.verify!

          start_new_account_session_for(verification_token.account) unless account_authenticated?
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
