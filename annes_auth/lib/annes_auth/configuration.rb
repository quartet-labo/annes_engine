module AnnesAuth
  class Configuration
    attr_accessor :account_class_name,
      :account_session_class_name,
      :account_identity_class_name,
      :account_verification_token_class_name,
      :account_password_reset_token_class_name,
      :account_invitation_token_class_name,
      :account_mailer_class_name,
      :account_table_name,
      :account_session_table_name,
      :account_identity_table_name,
      :account_verification_token_table_name,
      :account_password_reset_token_table_name,
      :account_invitation_token_table_name,
      :bootstrap_claim_table_name,
      :account_foreign_key,
      :account_session_cookie_name,
      :account_session_expires_in,
      :account_session_cookie_secure,
      :account_verification_digest_salt,
      :account_email_format,
      :account_password_minimum_length,
      :mailer_from,
      :google_oauth_client_id,
      :google_oauth_client_secret,
      :google_oauth_enabled,
      :after_account_login_path,
      :after_account_email_verification_path,
      :after_account_profile_completion_path,
      :account_profile_path,
      :account_password_reset_url,
      :account_invitation_url,
      :profile_complete,
      :after_account_created,
      :after_account_bootstrapped

    def initialize
      @account_class_name = "AnnesAuth::Account"
      @account_session_class_name = "AnnesAuth::AccountSession"
      @account_identity_class_name = "AnnesAuth::AccountIdentity"
      @account_verification_token_class_name = "AnnesAuth::AccountVerificationToken"
      @account_password_reset_token_class_name = "AnnesAuth::AccountPasswordResetToken"
      @account_invitation_token_class_name = "AnnesAuth::AccountInvitationToken"
      @account_mailer_class_name = "AnnesAuth::AccountMailer"
      @account_table_name = "accounts"
      @account_session_table_name = "account_sessions"
      @account_identity_table_name = "account_identities"
      @account_verification_token_table_name = "account_verification_tokens"
      @account_password_reset_token_table_name = "account_password_reset_tokens"
      @account_invitation_token_table_name = "account_invitation_tokens"
      @bootstrap_claim_table_name = "annes_auth_bootstrap_claims"
      @account_foreign_key = :account_id
      @account_session_cookie_name = :account_session_id
      @account_session_expires_in = 2.weeks
      @account_session_cookie_secure = ->(request) { request.ssl? || Rails.env.production? }
      # Keep the established key-derivation salt so verification codes issued
      # before the package rename remain valid until they expire.
      @account_verification_digest_salt = "anne_auth/account_verification_code"
      @account_email_format = URI::MailTo::EMAIL_REGEXP
      @account_password_minimum_length = 12
      @mailer_from = "noreply@example.com"
      @google_oauth_client_id = nil
      @google_oauth_client_secret = nil
      @google_oauth_enabled = false
      @after_account_login_path = ->(controller, _account) { controller.main_app.root_path }
      @after_account_email_verification_path = ->(controller, _account) { controller.main_app.root_path }
      @after_account_profile_completion_path = ->(controller, _account) { controller.main_app.root_path }
      @account_profile_path = ->(controller, _account) { controller.main_app.root_path }
      @account_password_reset_url = ->(mailer, token) { mailer.edit_account_password_reset_url(token:) }
      @account_invitation_url = ->(mailer, token) { mailer.account_invitation_url(token:) }
      @profile_complete = ->(_account) { true }
      @after_account_created = ->(_account, _controller) {}
      @after_account_bootstrapped = ->(_account) {}
    end

    def account_class
      account_class_name.constantize
    end

    def account_session_class
      account_session_class_name.constantize
    end

    def account_session_expires_at
      account_session_expires_in.from_now
    end

    def secure_account_session_cookie?(request)
      return account_session_cookie_secure.call(request) if account_session_cookie_secure.respond_to?(:call)

      account_session_cookie_secure
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

    def account_invitation_token_class
      account_invitation_token_class_name.constantize
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

    def account_bootstrapped(account)
      after_account_bootstrapped.call(account)
    end
  end
end
