require_relative "test_helper"

class AnnesLoyalty::EngineTest < AnnesLoyalty::TestCase
  test "engine is isolated and configured" do
    assert_equal "annes_loyalty", AnnesLoyalty::Engine.engine_name
    assert_instance_of AnnesLoyalty::Configuration, AnnesLoyalty.configuration
  end

  test "exposes only the AnnesLoyalty public package contract" do
    assert_equal "1.0.0", AnnesLoyalty::VERSION
    refute Object.const_defined?(:AnneLoyalty)
    assert_raises(LoadError) { require "anne_loyalty" }
  end
end
