require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"

Bundler.require(*Rails.groups)

require "annes_audit"

module Dummy
  class Application < Rails::Application
    config.root = File.expand_path("..", __dir__)
    config.load_defaults 8.1

    config.eager_load = false
    config.secret_key_base = "anne-audit-dummy-test-secret-key-base"
    config.hosts.clear
    config.cache_store = :null_store
  end
end
