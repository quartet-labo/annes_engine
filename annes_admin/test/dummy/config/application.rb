require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "active_job/railtie"
require "action_controller/railtie"
require "action_view/railtie"

Bundler.require(*Rails.groups)

require "annes_admin"

module Dummy
  class Application < Rails::Application
    config.root = File.expand_path("..", __dir__)
    config.load_defaults 8.1

    config.eager_load = false
    config.secret_key_base = "annes-admin-dummy-test-secret-key-base"
    config.hosts.clear
    config.cache_store = :null_store
  end
end
