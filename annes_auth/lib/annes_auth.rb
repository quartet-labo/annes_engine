require "annes_auth/version"
require "annes_auth/configuration"
require "annes_auth/account_event"
require "annes_auth/engine" if defined?(Rails::Engine)

module AnnesAuth
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
