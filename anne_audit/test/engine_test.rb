require_relative "test_helper"

class AnneAudit::EngineTest < AnneAudit::TestCase
  test "engine is isolated and configured" do
    assert_equal "anne_audit", AnneAudit::Engine.engine_name
    assert_instance_of AnneAudit::Configuration, AnneAudit.configuration
  end
end
