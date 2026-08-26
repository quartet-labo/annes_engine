module AnnesAudit
  class NotificationSubscriber
    def initialize(mapper:, recorder: AnnesAudit, logger: nil)
      @mapper = mapper
      @recorder = recorder
      @logger = logger
    end

    def call(event)
      attributes = mapper.call(event)
      return if empty_attributes?(attributes)

      recorder.record!(**attributes)
    rescue StandardError => error
      raise if AnnesAudit.configuration.raise_on_persistence_error

      log_persistence_error(error)
      nil
    end

    private
      attr_reader :mapper, :recorder, :logger

      def empty_attributes?(attributes)
        attributes.nil? || (attributes.respond_to?(:empty?) && attributes.empty?)
      end

      def log_persistence_error(error)
        audit_logger&.error("AnnesAudit failed to persist audit event: #{error.class.name}: #{error.message}")
      end

      def audit_logger
        logger || (Rails.logger if defined?(Rails) && Rails.respond_to?(:logger))
      end
  end
end
