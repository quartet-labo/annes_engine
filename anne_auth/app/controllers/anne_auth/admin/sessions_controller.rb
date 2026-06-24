module AnneAuth
  module Admin
    class SessionsController < AnneAuth::ApplicationController
      layout "admin_auth"

      rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to auth_route(:admin_login_path), alert: "時間をおいて再度お試しください。" }

      def new
        redirect_to auth_route(:admin_root_path) if admin_authenticated?
      end

      def create
        if admin_user = AnneAuth.configuration.admin_user_class.authenticate_by(session_params)
          admin_user.update!(last_sign_in_at: Time.current)
          start_new_admin_session_for(admin_user)
          redirect_to after_admin_authentication_url, notice: "ログインしました。"
        else
          redirect_to auth_route(:admin_login_path), alert: "メールアドレスまたはパスワードが正しくありません。"
        end
      end

      def destroy
        terminate_admin_session
        redirect_to auth_route(:admin_login_path), status: :see_other, notice: "ログアウトしました。"
      end

      private
        def session_params
          params.permit(:email, :password)
        end
    end
  end
end
