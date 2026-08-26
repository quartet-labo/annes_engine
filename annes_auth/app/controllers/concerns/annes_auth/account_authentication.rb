module AnnesAuth
  module AccountAuthentication
    extend ActiveSupport::Concern

    include RouteResolution

    included do
      helper_method :account_authenticated?, :account_profile_complete?, :current_account
    end

    private
      def account_authenticated?
        current_account_session.present?
      end

      def current_account
        current_account_session&.account
      end

      def require_account_authentication
        return true if current_account_session.present?

        request_account_authentication
        false
      end

      def require_verified_account
        return false unless require_account_authentication

        unless current_account.email_verified?
          redirect_to auth_route(:account_email_verification_pending_path), alert: "メール認証を完了してください。"
          return false
        end

        require_account_profile
      end

      def current_account_session
        AnnesAuth::Current.account_session ||= find_account_session_by_cookie
      end

      def account_profile_complete?
        AnnesAuth.configuration.profile_complete?(current_account)
      end

      def require_account_profile
        return true if account_profile_complete?

        session[:return_to_after_account_profile_completion] = request.fullpath
        redirect_to AnnesAuth.configuration.account_profile_path.call(self, current_account), alert: "顧客情報を入力してください。"
        false
      end

      def find_account_session_by_cookie
        cookie_name = AnnesAuth.configuration.account_session_cookie_name
        return if cookies.signed[cookie_name].blank?

        account_session = AnnesAuth.configuration.account_session_class.includes(:account).find_by(id: cookies.signed[cookie_name])
        return if account_session.blank?
        if account_session.expired? || account_session.account.disabled?
          account_session.destroy
          cookies.delete(cookie_name)
          return
        end

        account_session.record_use!
        account_session
      end

      def request_account_authentication
        session[:return_to_after_account_authenticating] = request.fullpath
        redirect_to auth_route(:account_login_path), alert: "ログインが必要です。"
      end

      def after_account_authentication_url
        AnnesAuth.configuration.after_account_login_path.call(self, current_account)
      end

      def after_account_profile_completion_url
        AnnesAuth.configuration.after_account_profile_completion_path.call(self, current_account)
      end

      def redirect_authenticated_account(verified_notice: nil)
        unless current_account.email_verified?
          redirect_to auth_route(:account_email_verification_pending_path), alert: "メール認証を完了してください。"
          return
        end

        redirect_options = {}
        redirect_options[:notice] = verified_notice if verified_notice.present?

        redirect_to after_account_authentication_url, **redirect_options
      end

      def start_new_account_session_for(account)
        expires_at = AnnesAuth.configuration.account_session_expires_at

        account.account_sessions.create!(
          user_agent: request.user_agent,
          ip_address: request.remote_ip,
          expires_at:,
          last_used_at: Time.current
        ).tap do |account_session|
          AnnesAuth::Current.account_session = account_session
          cookies.signed[AnnesAuth.configuration.account_session_cookie_name] = {
            value: account_session.id,
            expires: expires_at,
            httponly: true,
            same_site: :lax,
            secure: AnnesAuth.configuration.secure_account_session_cookie?(request)
          }
        end
      end

      def terminate_account_session
        current_account_session&.destroy
        AnnesAuth::Current.account_session = nil
        cookies.delete(AnnesAuth.configuration.account_session_cookie_name)
      end
  end
end
