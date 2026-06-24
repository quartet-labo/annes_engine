require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "active_job/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "action_mailer/railtie"

Bundler.require(*Rails.groups)

require "anne_auth"

module Dummy
  class Application < Rails::Application
    config.root = File.expand_path("..", __dir__)
    config.load_defaults 8.1

    config.eager_load = false
    config.secret_key_base = "anne-auth-dummy-test-secret-key-base"
    config.hosts.clear
    config.cache_store = :null_store
    config.action_mailer.delivery_method = :test
    config.action_mailer.default_url_options = { host: "example.test" }
  end
end
