require "annes_audit/version"
require "annes_audit/notification_subscriber"
require "annes_audit/notification_subscribers"
require "annes_audit/configuration"
require "annes_audit/errors"
require "annes_audit/metadata_filter"
require "annes_audit/reference"
require "annes_audit/context"
require "annes_audit/recorder"
require "annes_audit/mappers/annes_admin"
require "annes_audit/mappers/annes_auth"
require "annes_audit/engine" if defined?(Rails::Engine)

module AnnesAudit
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
