require_relative "../test_helper"

class AnnesAudit::NotificationPersistenceTest < AnnesAudit::TestCase
  test "persists registered notification through mapper" do
    AnnesAudit.configuration.notification_subscribers.register(
      "annes_admin.audit",
      mapper: AnnesAudit::Mappers::AnnesAdmin
    )
    AnnesAudit.configuration.notification_subscribers.subscribe_all!

    assert_difference -> { AnnesAudit::Event.count }, 1 do
      ActiveSupport::Notifications.instrument(
        "annes_admin.audit",
        resource: "customers",
        action: "update",
        record_id: "123",
        user_id: "42",
        status: "success"
      )
    end

    event = AnnesAudit::Event.order(:created_at).last
    assert_equal "annes_admin", event.source
    assert_equal "update", event.action
    assert_equal "success", event.result
    assert_equal "42", event.actor_id
    assert_equal "customers", event.target_type
    assert_equal "123", event.target_id
  end

  test "persists multiple notifications from the same instrumenter with unique event ids" do
    AnnesAudit.configuration.notification_subscribers.register(
      "annes_admin.audit",
      mapper: AnnesAudit::Mappers::AnnesAdmin
    )
    AnnesAudit.configuration.notification_subscribers.subscribe_all!

    assert_difference -> { AnnesAudit::Event.count }, 2 do
      2.times do |index|
        ActiveSupport::Notifications.instrument(
          "annes_admin.audit",
          resource: "customers",
          action: "update",
          record_id: index.to_s,
          user_id: "42",
          status: "success"
        )
      end
    end

    event_ids = AnnesAudit::Event.order(:created_at).last(2).map(&:event_id)
    assert_equal 2, event_ids.uniq.size
  end
end
