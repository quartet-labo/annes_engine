require_relative "../../test_helper"

class AnnesAudit::NotificationSubscribersTest < AnnesAudit::TestCase
  Mapper = ->(event) {
    {
      source: "test",
      action: event.payload.fetch(:action)
    }
  }

  test "registers unique notification mappers" do
    registry = AnnesAudit::NotificationSubscribers.new

    first = registry.register("audit.test", mapper: Mapper)
    second = registry.register("audit.test", mapper: Mapper)

    assert_same first, second
    assert_equal 1, registry.registrations.size
    assert_equal "audit.test", first.event_name
    assert_same Mapper, first.mapper
  end

  test "rejects mapper without call contract" do
    registry = AnnesAudit::NotificationSubscribers.new

    assert_raises(ArgumentError) { registry.register("audit.test", mapper: Object.new) }
  end

  test "subscribes registered notifications once" do
    registry = AnnesAudit::NotificationSubscribers.new
    registry.register("audit.test", mapper: Mapper)
    registry.subscribe_all!
    registry.subscribe_all!

    assert_difference -> { AnnesAudit::Event.count }, 1 do
      ActiveSupport::Notifications.instrument("audit.test", action: "created")
    end
  ensure
    registry&.unsubscribe_all!
  end
end
