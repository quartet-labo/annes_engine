AnneAuth.configure do |config|
  config.mailer_from = "noreply@example.com"
  config.google_oauth_enabled = false
  config.account_class_name = "Account"
  config.after_account_login_path = ->(controller, _account) { controller.main_app.admin_root_path }
end
