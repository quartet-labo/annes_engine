require_relative "boot"
require "rails/all"
Bundler.require(*Rails.groups)

module InquiryDummy
  class Application < Rails::Application
    config.load_defaults 8.1
    config.root = File.expand_path("..", __dir__)
    config.paths["db/migrate"] = [ root.join("db/migrate").to_s, AnnesInquiry::Engine.root.join("db/migrate").to_s ]
    config.eager_load = false
    config.secret_key_base = "inquiry-dummy-test-secret-" * 4
    config.active_support.deprecation = :stderr
    config.action_mailer.delivery_method = :test
    config.action_mailer.default_url_options = { host: "example.com" }
    config.active_storage.service = :test
    config.active_storage.service_configurations = {
      "test" => { "service" => "Disk", "root" => root.join("tmp/storage").to_s }
    }
    config.hosts.clear
    config.action_dispatch.show_exceptions = :none
    config.action_controller.allow_forgery_protection = false
  end
end
