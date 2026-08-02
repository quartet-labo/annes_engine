require_relative "../test_helper"

class AnneAudit::NotificationPersistenceTest < AnneAudit::TestCase
  test "persists registered notification through mapper" do
    AnneAudit.configuration.notification_subscribers.register(
      "anne_admin.audit",
      mapper: AnneAudit::Mappers::AnneAdmin
    )
    AnneAudit.configuration.notification_subscribers.subscribe_all!

    assert_difference -> { AnneAudit::Event.count }, 1 do
      ActiveSupport::Notifications.instrument(
        "anne_admin.audit",
        resource: "customers",
        action: "update",
        record_id: "123",
        user_id: "42",
        status: "success"
      )
    end

    event = AnneAudit::Event.order(:created_at).last
    assert_equal "anne_admin", event.source
    assert_equal "update", event.action
    assert_equal "success", event.result
    assert_equal "42", event.actor_id
    assert_equal "customers", event.target_type
    assert_equal "123", event.target_id
  end
end
