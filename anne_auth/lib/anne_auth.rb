require "anne_auth/version"
require "anne_auth/configuration"
require "anne_auth/account_event"
require "anne_auth/engine" if defined?(Rails::Engine)

module AnneAuth
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
