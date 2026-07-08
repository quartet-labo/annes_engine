module AnneAuth
  module AdminAuthentication
    extend ActiveSupport::Concern

    include Authentication
    include RouteResolution

    included do
      helper_method :admin_authenticated?, :current_admin_user
    end

    private
      def admin_authenticated?
        authenticated?
      end

      def current_admin_user
        current_user
      end

      def require_admin_authentication
        require_authentication
      end

      def current_admin_session
        current_session
      end

      def find_admin_session_by_cookie
        find_session_by_cookie
      end

      def request_admin_authentication
        session[:return_to_after_admin_authenticating] = request.fullpath
        redirect_to auth_route(:admin_login_path), alert: "管理者ログインが必要です。"
      end

      def after_admin_authentication_url
        AnneAuth.configuration.after_admin_login_path.call(self, current_admin_user)
      end

      def start_new_admin_session_for(admin_user)
        start_new_session_for(admin_user)
      end

      def terminate_admin_session
        terminate_session
      end
  end
end
