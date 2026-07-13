module Admin
  class SessionsController < ApplicationController
    layout "admin_auth"

    rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to main_app.admin_login_path, alert: "時間をおいて再度お試しください。" }

    def new
      redirect_to main_app.admin_root_path if account_authenticated?
    end

    def create
      account = AnneAuth.configuration.account_class.authenticate_by(session_params)

      if account&.disabled?
        reject_login
      elsif account
        account.update!(last_sign_in_at: Time.current)
        start_new_account_session_for(account)
        redirect_to main_app.admin_root_path, notice: "ログインしました。"
      else
        reject_login
      end
    end

    def destroy
      terminate_account_session
      redirect_to main_app.admin_login_path, status: :see_other, notice: "ログアウトしました。"
    end

    private
      def session_params
        params.permit(:email, :password)
      end

      def reject_login
        redirect_to main_app.admin_login_path, alert: "メールアドレスまたはパスワードが正しくありません。"
      end
  end
end
