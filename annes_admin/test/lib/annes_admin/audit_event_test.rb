require_relative "../../test_helper"

class AnnesAdmin::AuditEventTest < AnnesAdmin::TestCase
  test "emits audit event payload" do
    resource = AnnesAdmin::ResourceConfig.new(:customers, model: "Customer")
    user = Struct.new(:id).new(123)
    payloads = []

    ActiveSupport::Notifications.subscribed(->(*args) { payloads << ActiveSupport::Notifications::Event.new(*args).payload }, AnnesAdmin::AuditEvent::EVENT_NAME) do
      AnnesAdmin::AuditEvent.emit(resource:, action: :update, record: customers(:anan), user:, status: :success)
    end

    assert_equal "customers", payloads.first.fetch(:resource)
    assert_equal "update", payloads.first.fetch(:action)
    assert_equal customers(:anan).to_param, payloads.first.fetch(:record_id)
    assert_equal 123, payloads.first.fetch(:user_id)
    assert_equal "success", payloads.first.fetch(:status)
  end
end
