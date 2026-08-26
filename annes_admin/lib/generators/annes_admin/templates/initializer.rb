require "annes_admin"

AnnesAdmin.configure do |config|
  config.site_name = "Admin"

  config.authenticate_with do |controller|
    # Replace this with your application's admin authentication.
    controller.redirect_to(controller.main_app.root_path, alert: "Admin authentication is required.")
    false
  end

  config.current_user do |_controller|
    nil
  end

  # Resource files are loaded from app/admin/resources/*.rb and
  # config/annes_admin/resources/*.rb by default.
  # config.resource_paths << Rails.root.join("config/annes_admin/custom_resources")
end
