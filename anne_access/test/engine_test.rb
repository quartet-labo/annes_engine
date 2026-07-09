require_relative "test_helper"

class AnneAccess::EngineTest < AnneAccess::TestCase
  test "engine is isolated and configured" do
    assert_equal "anne_access", AnneAccess::Engine.engine_name
    assert_instance_of AnneAccess::Configuration, AnneAccess.configuration
  end
end
