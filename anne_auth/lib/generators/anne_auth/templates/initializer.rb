require "anne_auth"

AnneAuth.configure do |config|
  config.mailer_from = "noreply@example.com"
  config.account_mailer_class_name = "AnneAuth::AccountMailer"
  config.google_oauth_client_id = ENV["GOOGLE_OAUTH_CLIENT_ID"].presence
  config.google_oauth_client_secret = ENV["GOOGLE_OAUTH_CLIENT_SECRET"].presence
  config.google_oauth_enabled = config.google_oauth_client_id.present? && config.google_oauth_client_secret.present?

  # AnneAuth authenticates a host User by default.
  # If your app already has a User model, keep it and inherit from AnneAuth::User
  # or provide the same email/password_digest contract.
  # config.user_class_name = "User"
  # config.session_class_name = "AnneAuth::Session"
  # config.session_user_foreign_key = :user_id

  # Existing host apps that still use the legacy AdminUser/admin_user_id schema
  # can opt in explicitly while migrating:
  # config.admin_user_class_name = "AdminUser"
  # config.admin_session_class_name = "AnneAuth::AdminSession"
  # config.admin_session_user_foreign_key = :admin_user_id

  config.after_login_path = ->(controller, _user) { controller.main_app.root_url }
  config.after_admin_login_path = ->(controller, admin_user) { config.after_login_path.call(controller, admin_user) }
  config.after_account_login_path = ->(controller, _account) { controller.main_app.root_path }
  config.after_account_profile_completion_path = ->(controller, _account) { controller.main_app.root_path }
  config.account_profile_path = ->(controller, _account) { controller.main_app.root_path }
  config.profile_complete = ->(_account) { true }
  config.after_account_created = ->(_account, _controller) {}
end
