module AnneAuth
  module Accounts
    class RegistrationsController < AnneAuth::ApplicationController
      layout "anne_auth"

      rate_limit to: 5, within: 10.minutes, only: :create, with: -> { redirect_to auth_route(:new_account_registration_path), alert: "時間をおいて再度お試しください。" }
      rate_limit to: 3, within: 30.minutes, by: -> { registration_email_rate_limit_key }, name: "email", only: :create, with: -> { redirect_to auth_route(:new_account_registration_path), alert: "時間をおいて再度お試しください。" }

      def new
        if account_authenticated?
          redirect_authenticated_account
          return
        end

        build_registration_resources
      end

      def create
        build_registration_resources

        if save_registration
          start_new_account_session_for(@account)
          redirect_to auth_route(:account_email_verification_pending_path), notice: "アカウントを作成しました。メール認証を完了してください。"
        else
          render :new, status: :unprocessable_entity
        end
      end

      private
        def build_registration_resources
          @account = AnneAuth.configuration.account_class.new(account_params)
        end

        def save_registration
          return false unless @account.valid?

          AnneAuth.configuration.account_class.transaction do
            @account.save!
            AnneAuth.configuration.account_created(@account, self)
            deliver_verification_mail
          end

          true
        rescue ActiveRecord::RecordInvalid => error
          error.record.errors.full_messages.each { |message| @account.errors.add(:base, message) }
          false
        end

        def deliver_verification_mail
          _verification_token, plain_code = AnneAuth.configuration.account_verification_token_class.issue_for(@account)
          AnneAuth.configuration.account_mailer_class.with(account: @account, plain_code:).verification.deliver_now
        end

        def account_params
          params.fetch(:account, {}).permit(:email, :password, :password_confirmation)
        end

        def registration_email_rate_limit_key
          normalized_email = account_params[:email].to_s.strip.downcase.presence
          normalized_email || "ip:#{request.remote_ip}"
        end
    end
  end
end
