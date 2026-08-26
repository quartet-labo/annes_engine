require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "active_job/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "action_mailer/railtie"

Bundler.require(*Rails.groups)

require "annes_auth"
require "annes_admin"
require "annes_access"
require "anne_loyalty"

module RestaurantLoyalty
  class Application < Rails::Application
    config.load_defaults 8.1

    config.time_zone = "Tokyo"
    config.i18n.default_locale = :ja
    config.hosts.clear
    config.secret_key_base = ENV.fetch("SECRET_KEY_BASE", "restaurant-loyalty-sample-secret-key-base")
  end
end
