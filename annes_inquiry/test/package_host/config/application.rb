require_relative "boot"
require "rails/all"
Bundler.require(*Rails.groups)

module InquiryPackageHost
  class Application < Rails::Application
    config.load_defaults 8.1
    config.eager_load = false
    config.secret_key_base = "inquiry-package-test-secret-" * 4
    config.active_storage.service = :test
    config.active_storage.service_configurations = {
      "test" => { "service" => "Disk", "root" => root.join("tmp/storage").to_s }
    }
    config.hosts = ["www.example.com"]
    config.action_dispatch.show_exceptions = :none
    config.action_controller.allow_forgery_protection = true
  end
end
