AnneAuth.configure do |config|
  config.mailer_from = "noreply@example.com"
  config.google_oauth_enabled = false

  config.after_admin_login_path = ->(controller, _admin_user) { controller.main_app.admin_root_path }
end
