require_relative "../../test_helper"

class AnneAdmin::AuthenticationAdapterTest < AnneAdmin::TestCase
  test "delegates authentication to block" do
    controller = Object.new
    adapter = AnneAdmin::AuthenticationAdapter.new(->(passed_controller) { passed_controller.equal?(controller) })

    assert adapter.authenticate(controller)
  end

  test "can delegate to a controller authentication method" do
    controller = Class.new do
      attr_reader :authentication_requested

      def require_authentication
        @authentication_requested = true
      end
    end.new
    adapter = AnneAdmin::AuthenticationAdapter.new(->(passed_controller) { passed_controller.require_authentication })

    adapter.authenticate(controller)

    assert controller.authentication_requested
  end
end
