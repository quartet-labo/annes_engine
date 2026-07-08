module AnneAuth
  module Accounts
    class OmniauthCallbacksController < AnneAuth::ApplicationController
      layout "anne_auth"

      def create
        result = GoogleAuthentication.call(request.env["omniauth.auth"])

        if result.success?
          result.account.update!(last_sign_in_at: Time.current)
          start_new_account_session_for(result.account)

          if result.profile_required?
            session[:google_profile_name] = result.profile_name if result.profile_name.present?
            redirect_to AnneAuth.configuration.account_profile_path.call(self, result.account), notice: "Googleでログインしました。顧客情報を入力してください。"
          else
            redirect_to after_account_authentication_url, notice: "Googleでログインしました。"
          end
        else
          log_authentication_failure(result.status)
          redirect_to auth_route(:account_login_path), alert: failure_message
        end
      end

      def failure
        log_authentication_failure(params[:message])
        redirect_to auth_route(:account_login_path), alert: failure_message
      end

      private
        def failure_message
          "Googleログインに失敗しました。"
        end

        def log_authentication_failure(status)
          Rails.logger.info("Google login failed: #{status}")
        end
    end
  end
end
