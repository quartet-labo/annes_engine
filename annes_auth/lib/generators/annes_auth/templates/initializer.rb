require "annes_auth"

AnnesAuth.configure do |config|
  config.mailer_from = "noreply@example.com"
  config.account_mailer_class_name = "AnnesAuth::AccountMailer"
  config.google_oauth_client_id = ENV["GOOGLE_OAUTH_CLIENT_ID"].presence
  config.google_oauth_client_secret = ENV["GOOGLE_OAUTH_CLIENT_SECRET"].presence
  config.google_oauth_enabled = config.google_oauth_client_id.present? && config.google_oauth_client_secret.present?

  # AnnesAuth authenticates Account by default. Admin access should be decided by
  # the host app or annes_admin authorization.
  # config.account_class_name = "AnnesAuth::Account"
  # config.account_session_class_name = "AnnesAuth::AccountSession"
  # config.account_invitation_token_class_name = "AnnesAuth::AccountInvitationToken"
  # config.account_invitation_token_table_name = "account_invitation_tokens"
  # config.account_foreign_key = :account_id
  # config.account_password_minimum_length = 12
  # config.account_session_expires_in = 2.weeks
  # config.account_session_cookie_secure = ->(request) { request.ssl? || Rails.env.production? }

  config.after_account_login_path = ->(controller, _account) { controller.main_app.root_path }
  config.after_account_email_verification_path = ->(controller, _account) { controller.main_app.root_path }
  config.after_account_profile_completion_path = ->(controller, _account) { controller.main_app.root_path }
  config.account_profile_path = ->(controller, _account) { controller.main_app.root_path }
  config.account_invitation_url = ->(mailer, token) { mailer.account_invitation_url(token:) }
  config.profile_complete = ->(_account) { true }
  config.after_account_created = ->(_account, _controller) {}
  config.after_account_bootstrapped = ->(_account) {}
end
