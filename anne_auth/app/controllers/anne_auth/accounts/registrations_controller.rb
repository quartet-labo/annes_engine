module AnneAuth
  module Accounts
    class RegistrationsController < AnneAuth::ApplicationController
      layout "customer_auth"

      def new
        redirect_to auth_route(:root_path) if account_authenticated?

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
    end
  end
end
