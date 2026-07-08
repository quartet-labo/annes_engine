module AnneAuth
  module Authentication
    extend ActiveSupport::Concern

    include RouteResolution

    included do
      helper_method :authenticated?, :current_user
    end

    private
      def authenticated?
        current_session.present?
      end

      def current_user
        current_session&.user
      end

      def require_authentication
        return true if current_session.present?

        request_authentication
        false
      end

      def current_session
        AnneAuth::Current.session ||= find_session_by_cookie
      end

      def find_session_by_cookie
        cookie_name = AnneAuth.configuration.session_cookie_name
        return if cookies.signed[cookie_name].blank?

        session = AnneAuth.configuration.session_class.includes(:user).find_by(id: cookies.signed[cookie_name])
        return if session.blank?
        return session unless session.user.respond_to?(:disabled?) && session.user.disabled?

        session.destroy
        nil
      end

      def request_authentication
        session[:return_to_after_authenticating] = request.fullpath
        redirect_to auth_route(:login_path), alert: "ログインが必要です。"
      end

      def after_authentication_url
        AnneAuth.configuration.after_login_path.call(self, current_user)
      end

      def start_new_session_for(user)
        AnneAuth.configuration.session_class.create!(
          AnneAuth.configuration.session_user_foreign_key => user.id,
          user_agent: request.user_agent,
          ip_address: request.remote_ip
        ).tap do |auth_session|
          AnneAuth::Current.session = auth_session
          cookies.signed.permanent[AnneAuth.configuration.session_cookie_name] = {
            value: auth_session.id,
            httponly: true,
            same_site: :lax
          }
        end
      end

      def terminate_session
        current_session&.destroy
        AnneAuth::Current.session = nil
        cookies.delete(AnneAuth.configuration.session_cookie_name)
      end
  end
end
