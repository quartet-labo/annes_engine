module AnneAuth
  module Accounts
    class SessionsController < AnneAuth::ApplicationController
      layout "anne_auth"

      rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to auth_route(:account_login_path), alert: "時間をおいて再度お試しください。" }
      rate_limit to: 5, within: 15.minutes, by: -> { session_email_rate_limit_key }, name: "email", only: :create, with: -> { redirect_to auth_route(:account_login_path), alert: "時間をおいて再度お試しください。" }
      before_action :require_account_authentication_for_logout_confirmation, only: :confirm

      def new
        return unless account_authenticated?

        redirect_authenticated_account
      end

      def confirm
      end

      def create
        account = AnneAuth.configuration.account_class.authenticate_by(session_params)

        if account&.disabled?
          redirect_to auth_route(:account_login_path), alert: "メールアドレスまたはパスワードが正しくありません。"
        elsif account
          account.update!(last_sign_in_at: Time.current)
          account_session = start_new_account_session_for(account)
          AnneAuth::AccountEvent.emit(
            :sign_in,
            account:,
            account_session:,
            request:,
            auth_method: :password
          )
          if account.email_verified?
            redirect_to after_account_authentication_url, notice: "ログインしました。"
          else
            redirect_to auth_route(:account_email_verification_pending_path), alert: "メール認証を完了してください。"
          end
        else
          redirect_to auth_route(:account_login_path), alert: "メールアドレスまたはパスワードが正しくありません。"
        end
      end

      def destroy
        account_session = current_account_session
        AnneAuth::AccountEvent.emit(
          :sign_out,
          account: account_session&.account,
          account_session:,
          request:
        ) if account_session
        terminate_account_session
        redirect_to auth_route(:account_login_path), status: :see_other, notice: "ログアウトしました。"
      end

      private
        def session_params
          params.slice(:email, :password).permit(:email, :password)
        end

        def session_email_rate_limit_key
          normalized_email = session_params[:email].to_s.strip.downcase.presence
          normalized_email || "ip:#{request.remote_ip}"
        end

        def require_account_authentication_for_logout_confirmation
          return true if account_authenticated?

          redirect_to auth_route(:account_login_path), alert: "ログインが必要です。"
          false
        end
    end
  end
end
