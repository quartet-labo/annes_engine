AnnesInquiry.configure do |config|
  config.public_endpoints_enabled = true
  config.admin_authenticator = ->(controller) { :admin if controller.request.headers["X-Package-Admin"] == "yes" }
  config.admin_authorizer = ->(controller, user) { user == :admin }
end
