module AnneAuth
  module AdminAuthentication
    extend ActiveSupport::Concern

    include RouteResolution

    included do
      helper_method :admin_authenticated?, :current_admin_user
    end

    private
      def admin_authenticated?
        current_admin_session.present?
      end

      def current_admin_user
        current_admin_session&.admin_user
      end

      def require_admin_authentication
        current_admin_session || request_admin_authentication
      end

      def current_admin_session
        AnneAuth::Current.session ||= find_admin_session_by_cookie
      end

      def find_admin_session_by_cookie
        AnneAuth.configuration.admin_session_class.includes(:admin_user).find_by(id: cookies.signed[:admin_session_id]) if cookies.signed[:admin_session_id]
      end

      def request_admin_authentication
        session[:return_to_after_admin_authenticating] = request.fullpath
        redirect_to auth_route(:admin_login_path), alert: "管理者ログインが必要です。"
      end

      def after_admin_authentication_url
        AnneAuth.configuration.after_admin_login_path.call(self, current_admin_user)
      end

      def start_new_admin_session_for(admin_user)
        admin_user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |admin_session|
          AnneAuth::Current.session = admin_session
          cookies.signed.permanent[:admin_session_id] = { value: admin_session.id, httponly: true, same_site: :lax }
        end
      end

      def terminate_admin_session
        current_admin_session&.destroy
        AnneAuth::Current.session = nil
        cookies.delete(:admin_session_id)
      end
  end
end
