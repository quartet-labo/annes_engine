AnneAuth.configure do |config|
  config.mailer_from = "noreply@example.com"
  config.google_oauth_enabled = false

  config.after_login_path = ->(controller, _user) { controller.main_app.admin_root_path }
  config.after_admin_login_path = ->(controller, user) { config.after_login_path.call(controller, user) }
end
