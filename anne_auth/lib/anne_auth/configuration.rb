module AnneAuth
  class Configuration
    attr_accessor :admin_user_class_name,
      :admin_session_class_name,
      :account_class_name,
      :account_session_class_name,
      :account_identity_class_name,
      :account_verification_token_class_name,
      :account_password_reset_token_class_name,
      :account_mailer_class_name,
      :account_table_name,
      :account_session_table_name,
      :account_identity_table_name,
      :account_verification_token_table_name,
      :account_password_reset_token_table_name,
      :account_foreign_key,
      :account_session_cookie_name,
      :account_verification_digest_salt,
      :account_email_format,
      :mailer_from,
      :google_oauth_client_id,
      :google_oauth_client_secret,
      :google_oauth_enabled,
      :after_admin_login_path,
      :after_account_login_path,
      :after_account_profile_completion_path,
      :account_profile_path,
      :account_password_reset_url,
      :profile_complete,
      :after_account_created

    def initialize
      @admin_user_class_name = "AdminUser"
      @admin_session_class_name = "Session"
      @account_class_name = "AnneAuth::Account"
      @account_session_class_name = "AnneAuth::AccountSession"
      @account_identity_class_name = "AnneAuth::AccountIdentity"
      @account_verification_token_class_name = "AnneAuth::AccountVerificationToken"
      @account_password_reset_token_class_name = "AnneAuth::AccountPasswordResetToken"
      @account_mailer_class_name = "AnneAuth::AccountMailer"
      @account_table_name = "accounts"
      @account_session_table_name = "account_sessions"
      @account_identity_table_name = "account_identities"
      @account_verification_token_table_name = "account_verification_tokens"
      @account_password_reset_token_table_name = "account_password_reset_tokens"
      @account_foreign_key = :account_id
      @account_session_cookie_name = :account_session_id
      @account_verification_digest_salt = "anne_auth/account_verification_code"
      @account_email_format = URI::MailTo::EMAIL_REGEXP
      @mailer_from = "noreply@example.com"
      @google_oauth_client_id = nil
      @google_oauth_client_secret = nil
      @google_oauth_enabled = false
      @after_admin_login_path = ->(controller, _admin_user) { controller.main_app.admin_root_path }
      @after_account_login_path = ->(controller, _account) { controller.main_app.root_path }
      @after_account_profile_completion_path = ->(controller, _account) { controller.main_app.root_path }
      @account_profile_path = ->(controller, _account) { controller.main_app.root_path }
      @account_password_reset_url = ->(mailer, token) { mailer.edit_account_password_reset_url(token:) }
      @profile_complete = ->(_account) { true }
      @after_account_created = ->(_account, _controller) {}
    end

    def admin_user_class
      admin_user_class_name.constantize
    end

    def admin_session_class
      admin_session_class_name.constantize
    end

    def account_class
      account_class_name.constantize
    end

    def account_session_class
      account_session_class_name.constantize
    end

    def account_identity_class
      account_identity_class_name.constantize
    end

    def account_verification_token_class
      account_verification_token_class_name.constantize
    end

    def account_password_reset_token_class
      account_password_reset_token_class_name.constantize
    end

    def account_mailer_class
      account_mailer_class_name.constantize
    end

    def google_oauth_configured?
      google_oauth_enabled && google_oauth_client_id.present? && google_oauth_client_secret.present?
    end

    def profile_complete?(account)
      profile_complete.call(account)
    end

    def account_created(account, controller)
      after_account_created.call(account, controller)
    end
  end
end
