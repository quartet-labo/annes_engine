require "anne_audit/version"
require "anne_audit/configuration"
require "anne_audit/errors"
require "anne_audit/engine" if defined?(Rails::Engine)

module AnneAudit
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
