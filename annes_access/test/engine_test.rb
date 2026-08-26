require_relative "test_helper"

class AnnesAccess::EngineTest < AnnesAccess::TestCase
  test "engine is isolated and configured" do
    assert_equal "annes_access", AnnesAccess::Engine.engine_name
    assert_instance_of AnnesAccess::Configuration, AnnesAccess.configuration
  end

  test "exposes only the AnnesAccess public package contract" do
    assert_equal "1.0.0", AnnesAccess::VERSION
    refute Object.const_defined?(:AnneAccess)
    assert_raises(LoadError) { require "anne_access" }
  end
end
