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
require "anne_admin"
require "annes_access"

module ReservationManagement
  class Application < Rails::Application
    config.load_defaults 8.1

    config.time_zone = "Tokyo"
    config.active_record.default_timezone = :utc
    config.i18n.default_locale = :ja
    config.hosts.clear
    config.secret_key_base = ENV.fetch("SECRET_KEY_BASE", "reservation-management-sample-secret-key-base")
  end
end
