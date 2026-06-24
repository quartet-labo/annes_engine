require_relative "../../test_helper"

class AnneAdmin::AuthenticationAdapterTest < AnneAdmin::TestCase
  test "delegates authentication to block" do
    controller = Object.new
    adapter = AnneAdmin::AuthenticationAdapter.new(->(passed_controller) { passed_controller.equal?(controller) })

    assert adapter.authenticate(controller)
  end
end
