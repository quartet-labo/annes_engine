require_relative "test_helper"

class AnneAdmin::EngineTest < AnneAdmin::TestCase
  test "engine is isolated and configured" do
    assert_equal "anne_admin", AnneAdmin::Engine.engine_name
    assert_respond_to AnneAdmin::Engine.routes.url_helpers, :root_path
    assert_instance_of AnneAdmin::Configuration, AnneAdmin.configuration
  end
end
