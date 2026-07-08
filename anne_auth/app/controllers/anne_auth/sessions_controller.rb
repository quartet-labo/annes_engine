module AnneAuth
  class SessionsController < AnneAuth::ApplicationController
    layout "admin_auth"

    rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to auth_route(:login_path), alert: "時間をおいて再度お試しください。" }

    def new
      redirect_to main_app.root_path if authenticated?
    end

    def create
      if user = AnneAuth.configuration.user_class.authenticate_by(session_params)
        user.update!(last_sign_in_at: Time.current) if user.respond_to?(:last_sign_in_at)
        start_new_session_for(user)
        redirect_to after_authentication_url, notice: "ログインしました。"
      else
        redirect_to auth_route(:login_path), alert: "メールアドレスまたはパスワードが正しくありません。"
      end
    end

    def destroy
      terminate_session
      redirect_to auth_route(:login_path), status: :see_other, notice: "ログアウトしました。"
    end

    private
      def session_params
        params.permit(:email, :password)
      end
  end
end
