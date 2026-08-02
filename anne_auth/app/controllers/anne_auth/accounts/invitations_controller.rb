module AnneAuth
  module Accounts
    class InvitationsController < AnneAuth::ApplicationController
      INVITATION_SESSION_KEY = :anne_auth_account_invitation_id
      INVALID_INVITATION_MESSAGE = "招待リンクが無効または期限切れです。"

      layout "anne_auth"

      before_action :set_referrer_policy, only: :show

      def show
        lookup = invitation_token_class.lookup(params[:token])

        unless lookup.success?
          redirect_invalid_invitation
          return
        end

        session[INVITATION_SESSION_KEY] = lookup.invitation_token.id
        redirect_to auth_route(:edit_account_invitation_path), status: :see_other
      end

      def edit
        invitation_token = invitation_token_from_session

        unless acceptable?(invitation_token)
          redirect_invalid_invitation
          return
        end

        @account = invitation_token.account
      end

      def update
        invitation_token = invitation_token_from_session

        unless acceptable?(invitation_token)
          redirect_invalid_invitation
          return
        end

        clear_account_session_cookie = current_account_session&.account == invitation_token.account
        result = AnneAuth::Accounts::InvitationAcceptance.call(
          invitation_token:,
          password: invitation_params[:password],
          password_confirmation: invitation_params[:password_confirmation]
        )

        if result.success?
          clear_invitation_session
          clear_current_account_session_cookie if clear_account_session_cookie
          AnneAuth::AccountEvent.emit(
            :invitation_accepted,
            account: result.account,
            request:,
            auth_method: :invitation
          )
          redirect_to auth_route(:account_login_path),
            status: :see_other,
            notice: "アカウント設定が完了しました。ログインしてください。"
        elsif result.status == :invalid_password
          @account = result.account
          render :edit, status: :unprocessable_entity
        else
          redirect_invalid_invitation
        end
      end

      private
        def invitation_token_class
          AnneAuth.configuration.account_invitation_token_class
        end

        def invitation_token_from_session
          invitation_id = session[INVITATION_SESSION_KEY]
          return if invitation_id.blank?

          invitation_token_class.includes(:account).find_by(id: invitation_id)
        end

        def acceptable?(invitation_token)
          invitation_token.present? &&
            !invitation_token.used? &&
            !invitation_token.expired? &&
            !invitation_token.account.disabled? &&
            !invitation_token.account.email_verified?
        end

        def invitation_params
          params.permit(:password, :password_confirmation)
        end

        def redirect_invalid_invitation
          clear_invitation_session
          redirect_to auth_route(:account_login_path),
            status: :see_other,
            alert: INVALID_INVITATION_MESSAGE
        end

        def clear_invitation_session
          session.delete(INVITATION_SESSION_KEY)
        end

        def clear_current_account_session_cookie
          AnneAuth::Current.account_session = nil
          cookies.delete(AnneAuth.configuration.account_session_cookie_name)
        end

        def set_referrer_policy
          response.set_header("Referrer-Policy", "no-referrer")
        end
    end
  end
end
