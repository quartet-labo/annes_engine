module AnneAuth
  module Accounts
    class PasswordResetsController < AnneAuth::ApplicationController
      layout "anne_auth"

      rate_limit to: 5, within: 10.minutes, only: :create, with: -> { redirect_to auth_route(:new_account_password_reset_path), alert: "時間をおいて再度お試しください。" }

      def new
      end

      def create
        account = AnneAuth.configuration.account_class.active.find_by(email: password_reset_request_params[:email].to_s.strip.downcase)

        if account
          _password_reset_token, plain_token = password_reset_token_class.issue_for(account)
          AnneAuth.configuration.account_mailer_class.with(account:, plain_token:).password_reset.deliver_now
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
          clear_current_session_cookie = current_account_session&.account == @account

          AnneAuth.configuration.account_class.transaction do
            @account.save!
            password_reset_token_class.expire_active_for(@account)
            @account.account_sessions.destroy_all
          end

          clear_current_account_session_cookie if clear_current_session_cookie
          redirect_to auth_route(:account_login_path), notice: "パスワードを再設定しました。"
        else
          render :edit, status: :unprocessable_entity
        end
      end

      private
        def password_reset_request_params
          params.permit(:email)
        end

        def password_reset_params
          params.permit(:password, :password_confirmation)
        end

        def password_reset_lookup
          @password_reset_lookup ||= password_reset_token_class.lookup(@token)
        end

        def password_reset_token_class
          AnneAuth.configuration.account_password_reset_token_class
        end

        def clear_current_account_session_cookie
          AnneAuth::Current.account_session = nil
          cookies.delete(AnneAuth.configuration.account_session_cookie_name)
        end

        def redirect_invalid_token
          redirect_to auth_route(:new_account_password_reset_path), alert: "パスワード再設定リンクが無効または期限切れです。"
        end
    end
  end
end
