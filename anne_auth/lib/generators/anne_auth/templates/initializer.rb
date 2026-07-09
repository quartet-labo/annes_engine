require "anne_auth"

AnneAuth.configure do |config|
  config.mailer_from = "noreply@example.com"
  config.account_mailer_class_name = "AnneAuth::AccountMailer"
  config.google_oauth_client_id = ENV["GOOGLE_OAUTH_CLIENT_ID"].presence
  config.google_oauth_client_secret = ENV["GOOGLE_OAUTH_CLIENT_SECRET"].presence
  config.google_oauth_enabled = config.google_oauth_client_id.present? && config.google_oauth_client_secret.present?

  # AnneAuth authenticates Account by default. Admin access should be decided by
  # the host app or anne_admin authorization.
  # config.account_class_name = "AnneAuth::Account"
  # config.account_session_class_name = "AnneAuth::AccountSession"
  # config.account_foreign_key = :account_id
  # config.account_password_minimum_length = 12

  config.after_account_login_path = ->(controller, _account) { controller.main_app.root_path }
  config.after_account_email_verification_path = ->(controller, _account) { controller.main_app.root_path }
  config.after_account_profile_completion_path = ->(controller, _account) { controller.main_app.root_path }
  config.account_profile_path = ->(controller, _account) { controller.main_app.root_path }
  config.profile_complete = ->(_account) { true }
  config.after_account_created = ->(_account, _controller) {}
end
