Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = false
  config.consider_all_requests_local = true
  config.action_controller.allow_forgery_protection = false
  config.cache_store = :memory_store
  config.active_support.deprecation = :stderr
  config.action_mailer.delivery_method = :test
  config.action_mailer.default_url_options = { host: "example.test" }
end
