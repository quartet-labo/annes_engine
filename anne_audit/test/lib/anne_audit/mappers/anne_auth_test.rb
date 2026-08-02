require_relative "../../../test_helper"

class AnneAudit::Mappers::AnneAuthTest < AnneAudit::TestCase
  test "maps anne_auth account event payload to record attributes" do
    event = notification_event(
      "anne_auth.account_event",
      event: "sign_in",
      account_id: "123",
      account_class: "Account",
      account_email: "owner@example.com",
      session_id: "session-1",
      auth_method: "password",
      provider: "credentials",
      ip_address: "203.0.113.10",
      user_agent: "Mozilla/5.0",
      status: "success",
      metadata: { source: "login_form" }
    )

    attributes = AnneAudit::Mappers::AnneAuth.call(event)

    assert_equal event.transaction_id, attributes.fetch(:event_id)
    assert_equal "anne_auth", attributes.fetch(:source)
    assert_equal "sign_in", attributes.fetch(:action)
    assert_equal "success", attributes.fetch(:result)
    assert_equal({ type: "Account", id: "123", label: "owner@example.com" }, attributes.fetch(:actor))
    assert_equal({ type: "Account", id: "123", label: "owner@example.com" }, attributes.fetch(:target))
    assert_equal "203.0.113.10", attributes.fetch(:ip_address)
    assert_equal "Mozilla/5.0", attributes.fetch(:user_agent)
    assert_equal "session-1", attributes.fetch(:metadata).fetch(:session_id)
    assert_equal({ source: "login_form" }, attributes.fetch(:metadata).fetch(:metadata))
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
