require_relative "test_helper"

class AnneLoyalty::EngineTest < AnneLoyalty::TestCase
  test "engine is isolated and configured" do
    assert_equal "anne_loyalty", AnneLoyalty::Engine.engine_name
    assert_instance_of AnneLoyalty::Configuration, AnneLoyalty.configuration
  end
end
