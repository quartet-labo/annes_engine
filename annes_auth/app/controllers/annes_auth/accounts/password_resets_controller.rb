module AnnesAuth
  module Accounts
    class PasswordResetsController < AnnesAuth::ApplicationController
      layout "annes_auth"

      rate_limit to: 5, within: 10.minutes, only: :create, with: -> { redirect_to auth_route(:new_account_password_reset_path), alert: "時間をおいて再度お試しください。" }
      rate_limit to: 3, within: 30.minutes, by: -> { password_reset_email_rate_limit_key }, name: "email", only: :create, with: -> { redirect_to auth_route(:new_account_password_reset_path), alert: "時間をおいて再度お試しください。" }

      def new
      end

      def create
        account = AnnesAuth.configuration.account_class.active.find_by(email: password_reset_request_params[:email].to_s.strip.downcase)

        if account
          _password_reset_token, plain_token = password_reset_token_class.issue_for(account)
          AnnesAuth.configuration.account_mailer_class.with(account:, plain_token:).password_reset.deliver_now
          AnnesAuth::AccountEvent.emit(
            :password_reset_requested,
            account:,
            request:,
            auth_method: :password_reset
          )
        end

        redirect_to auth_route(:account_login_path), notice: "登録済みのメールアドレスの場合、パスワード再設定メールを送信しました。"
      end

      def edit
        @token = params[:token].to_s
        redirect_invalid_token unless password_reset_lookup.success?
      end

      def update
        @token = params[:token].to_s
        lookup = password_reset_token_class.lookup(@token)

        unless lookup.success?
          redirect_invalid_token
          return
        end

        password_reset_token = lookup.password_reset_token
        @account = password_reset_token.account
        @account.assign_attributes(password_reset_params)
        @account.errors.add(:password, :blank) if password_reset_params[:password].blank?

        if @account.errors.none? && @account.valid?
          reset_account_session = current_account_session if current_account_session&.account == @account

          AnnesAuth.configuration.account_class.transaction do
            @account.save!
            password_reset_token_class.expire_active_for(@account)
            @account.account_sessions.destroy_all
          end

          clear_current_account_session_cookie if reset_account_session
          AnnesAuth::AccountEvent.emit(
            :password_reset_completed,
            account: @account,
            account_session: reset_account_session,
            request:,
            auth_method: :password_reset
          )
          redirect_to auth_route(:account_login_path), notice: "パスワードを再設定しました。"
        else
          render :edit, status: :unprocessable_entity
        end
      end

      private
        def password_reset_request_params
          params.permit(:email)
        end

        def password_reset_email_rate_limit_key
          normalized_email = password_reset_request_params[:email].to_s.strip.downcase.presence
          normalized_email || "ip:#{request.remote_ip}"
        end

        def password_reset_params
          params.permit(:password, :password_confirmation)
        end

        def password_reset_lookup
          @password_reset_lookup ||= password_reset_token_class.lookup(@token)
        end

        def password_reset_token_class
          AnnesAuth.configuration.account_password_reset_token_class
        end

        def clear_current_account_session_cookie
          AnnesAuth::Current.account_session = nil
          cookies.delete(AnnesAuth.configuration.account_session_cookie_name)
        end

        def redirect_invalid_token
          redirect_to auth_route(:new_account_password_reset_path), alert: "パスワード再設定リンクが無効または期限切れです。"
        end
    end
  end
end
