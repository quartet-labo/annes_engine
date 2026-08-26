require "anne_audit/version"
require "anne_audit/notification_subscriber"
require "anne_audit/notification_subscribers"
require "anne_audit/configuration"
require "anne_audit/errors"
require "anne_audit/metadata_filter"
require "anne_audit/reference"
require "anne_audit/context"
require "anne_audit/recorder"
require "anne_audit/mappers/annes_admin"
require "anne_audit/mappers/annes_auth"
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

    def record!(**attributes)
      Recorder.call(**attributes)
    end

    def record(**attributes)
      record!(**attributes)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid
      false
    end

    def with_context(**values, &block)
      Context.with(values, &block)
    end
  end
end
