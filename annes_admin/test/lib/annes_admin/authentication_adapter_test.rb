require_relative "../../test_helper"

class AnnesAdmin::AuthenticationAdapterTest < AnnesAdmin::TestCase
  test "delegates authentication to block" do
    controller = Object.new
    adapter = AnnesAdmin::AuthenticationAdapter.new(->(passed_controller) { passed_controller.equal?(controller) })

    assert adapter.authenticate(controller)
  end

  test "can delegate to a controller authentication method" do
    controller = Class.new do
      attr_reader :authentication_requested

      def require_account_authentication
        @authentication_requested = true
      end
    end.new
    adapter = AnnesAdmin::AuthenticationAdapter.new(->(passed_controller) { passed_controller.require_account_authentication })

    adapter.authenticate(controller)

    assert controller.authentication_requested
  end
end
