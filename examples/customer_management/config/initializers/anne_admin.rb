Rails.application.config.to_prepare do
  AnneAdmin::ApplicationController.include AnneAuth::AdminAuthentication
end

AnneAdmin.configure do |config|
  config.site_name = "社内顧客管理"

  config.authenticate_with do |controller|
    controller.send(:require_admin_authentication)
  end

  config.current_user do |controller|
    controller.send(:current_user)
  end

  config.authorize_with do |context|
    context[:user]&.role == "admin"
  end
end
