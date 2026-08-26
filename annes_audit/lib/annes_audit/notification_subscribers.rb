module AnnesAudit
  class NotificationSubscribers
    Registration = Struct.new(:event_name, :mapper, keyword_init: true)

    attr_reader :registrations

    def initialize
      @registrations = []
      @subscriptions = {}
    end

    def register(event_name, mapper:)
      normalized_event_name = event_name.to_s
      validate_mapper!(mapper)

      existing = registrations.find { |registration| registration.event_name == normalized_event_name && registration.mapper == mapper }
      return existing if existing

      Registration.new(event_name: normalized_event_name, mapper:).tap do |registration|
        registrations << registration
      end
    end

    def subscribe_all!
      registrations.each { |registration| subscribe(registration) }
    end

    def unsubscribe_all!
      subscriptions.each_value { |subscription| ActiveSupport::Notifications.unsubscribe(subscription) }
      subscriptions.clear
    end

    private
      attr_reader :subscriptions

      def subscribe(registration)
        key = subscription_key(registration)
        return subscriptions[key] if subscriptions.key?(key)

        subscriber = NotificationSubscriber.new(mapper: registration.mapper)
        subscriptions[key] = ActiveSupport::Notifications.subscribe(registration.event_name) do |*args|
          subscriber.call(ActiveSupport::Notifications::Event.new(*args))
        end
      end

      def subscription_key(registration)
        [ registration.event_name, registration.mapper ]
      end

      def validate_mapper!(mapper)
        return if mapper.respond_to?(:call)

        raise ArgumentError, "notification mapper must respond to call"
      end
  end
end
