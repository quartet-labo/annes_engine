require_relative "../../../test_helper"

class AnneAudit::Mappers::AnnesAdminTest < AnneAudit::TestCase
  test "maps annes_admin audit payload to record attributes" do
    event = notification_event(
      "annes_admin.audit",
      resource: "customers",
      action: "update",
      record_id: "123",
      user_id: "42",
      status: "success"
    )

    attributes = AnneAudit::Mappers::AnnesAdmin.call(event)

    refute_includes attributes, :event_id
    assert_equal "annes_admin", attributes.fetch(:source)
    assert_equal "update", attributes.fetch(:action)
    assert_equal "success", attributes.fetch(:result)
    assert_equal({ id: "42", label: "42" }, attributes.fetch(:actor))
    assert_equal({ type: "customers", id: "123" }, attributes.fetch(:target))
    assert_equal "customers", attributes.fetch(:metadata).fetch(:resource)
    assert attributes.fetch(:metadata).key?(:duration_ms)
  end

  private
    def notification_event(name, **payload)
      captured = nil
      ActiveSupport::Notifications.subscribed(->(*args) { captured = ActiveSupport::Notifications::Event.new(*args) }, name) do
        ActiveSupport::Notifications.instrument(name, **payload)
      end
      captured
    end
end
