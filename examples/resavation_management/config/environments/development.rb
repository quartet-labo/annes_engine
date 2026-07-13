Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.server_timing = true

  config.active_record.migration_error = :page_load
  config.active_record.verbose_query_logs = true

  config.action_controller.perform_caching = false
  config.action_mailer.delivery_method = :file
  config.action_mailer.file_settings = { location: Rails.root.join("tmp/mail") }
  config.action_mailer.default_url_options = { host: "localhost", port: 3000 }

  config.assets.quiet = true if config.respond_to?(:assets)
end
