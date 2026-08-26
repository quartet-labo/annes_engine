require_relative "test_helper"

class AnnesAdmin::EngineTest < AnnesAdmin::TestCase
  test "engine is isolated and configured" do
    assert_equal "annes_admin", AnnesAdmin::Engine.engine_name
    assert_respond_to AnnesAdmin::Engine.routes.url_helpers, :root_path
    assert_instance_of AnnesAdmin::Configuration, AnnesAdmin.configuration
  end

  test "exposes only the AnnesAdmin public package contract" do
    assert_equal "1.0.0", AnnesAdmin::VERSION
    refute Object.const_defined?(:AnneAdmin)
    assert_raises(LoadError) { require "anne_admin" }
  end
end
