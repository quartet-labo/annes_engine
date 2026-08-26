require_relative "../../test_helper"

class AnnesAdmin::ResourceActionsControllerTest < AnnesAdmin::IntegrationTest
  setup do
    AnnesAdmin.configure do |config|
      config.authenticate_with { true }
      config.current_user { Struct.new(:email).new("admin@example.com") }
      config.resource :customers, model: "Customer" do
        field :contact_name
        permitted_attributes :contact_name
        custom_action :normalize_name, method: :post, scope: :member, label: "Normalize" do |record:, **|
          record.update!(contact_name: record.contact_name.strip)
        end
      end
    end
  end

  test "runs member custom action and emits audit event" do
    customer = customers(:anan)
    customer.update!(contact_name: "  #{customer.contact_name}  ")
    payloads = []

    ActiveSupport::Notifications.subscribed(->(*args) { payloads << ActiveSupport::Notifications::Event.new(*args).payload }, AnnesAdmin::AuditEvent::EVENT_NAME) do
      post annes_admin.resource_member_action_path("customers", customer, "normalize_name")
    end

    assert_redirected_to annes_admin.resource_record_path("customers", customer)
    assert_equal customer.contact_name.strip, customer.reload.contact_name
    assert_equal "normalize_name", payloads.last.fetch(:action)
  end

  test "shows member custom action when authorization is not configured" do
    customer = customers(:anan)

    get annes_admin.resource_record_path("customers", customer)

    assert_response :success
    assert_includes response.body, "Normalize"
  end

  test "rejects wrong http method" do
    customer = customers(:anan)

    patch annes_admin.resource_member_action_path("customers", customer, "normalize_name")

    assert_response :method_not_allowed
  end
end
